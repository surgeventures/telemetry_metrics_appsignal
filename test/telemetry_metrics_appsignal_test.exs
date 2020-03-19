defmodule TelemetryMetricsAppsignalTest do
  use ExUnit.Case

  import Telemetry.Metrics
  import Hammox

  alias Telemetry.Metrics.Counter
  alias Telemetry.Metrics.Distribution
  alias Telemetry.Metrics.LastValue
  alias Telemetry.Metrics.Sum
  alias Telemetry.Metrics.Summary

  @handler_prefix "telemetry_metrics_appsignal"
  @moduletag capture_log: true

  setup :verify_on_exit!

  test "attaching and detaching telemetry handlers" do
    metrics = [
      counter("web.request.count"),
      distribution("web.request.duration", buckets: [100, 200, 400]),
      last_value("worker.queue.length"),
      sum("worker.events.consumed"),
      summary("db.query.duration")
    ]

    TelemetryMetricsAppsignal.attach(metrics)

    attached_handlers = :telemetry.list_handlers([])

    event_metrics = %{
      [:web, :request] => [Counter, Distribution],
      [:worker, :queue] => [LastValue],
      [:worker, :events] => [Sum],
      [:db, :query] => [Summary]
    }

    Enum.each(event_metrics, fn {event_name, expected_metrics} ->
      handler_id = [@handler_prefix | event_name] |> Enum.join("_")
      handler = Enum.find(attached_handlers, &(&1.id == handler_id))
      handler_metrics = handler.config[:metrics]

      assert handler.event_name == event_name
      assert Enum.map(handler_metrics, & &1.__struct__()) == expected_metrics
    end)

    TelemetryMetricsAppsignal.detach(metrics)
    attached_handlers = :telemetry.list_handlers([])
    assert attached_handlers == []
  end

  test "allwing to configure handler namespace" do
    metric = counter("web.request.count")
    TelemetryMetricsAppsignal.attach([metric], namespace: "api")
    TelemetryMetricsAppsignal.attach([metric], namespace: "rpc")
    attached_handlers = :telemetry.list_handlers([])

    handler_ids =
      attached_handlers
      |> Enum.map(& &1.id)
      |> Enum.sort()

    assert handler_ids == [
             "telemetry_metrics_appsignal_api_web_request",
             "telemetry_metrics_appsignal_rpc_web_request"
           ]

    TelemetryMetricsAppsignal.detach([metric], namespace: "api")
    TelemetryMetricsAppsignal.detach([metric], namespace: "rpc")
    attached_handlers = :telemetry.list_handlers([])
    assert attached_handlers == []
  end

  test "reporting counter metrics" do
    parent = self()

    # `Telemetry.Metrics.Counter` and `Telemetry.Metrics.Sum`
    # both map to AppSignal's counter metric
    metrics = [
      counter("web.request.count"),
      sum("worker.events.consumed")
    ]

    TelemetryMetricsAppsignal.attach(metrics)

    ref = make_ref()

    expect(AppsignalMock, :increment_counter, fn
      "web.request.count", 1, %{} ->
        send(parent, {ref, :called})
        :ok
    end)

    :telemetry.execute([:web, :request], %{}, %{})
    assert_receive {^ref, :called}

    # Measurements should be ignored for counter metric
    ref = make_ref()

    expect(AppsignalMock, :increment_counter, fn "web.request.count", 1, _tags ->
      send(parent, {ref, :called})
      :ok
    end)

    :telemetry.execute([:web, :request], %{count: 5}, %{})
    assert_receive {^ref, :called}

    ref = make_ref()

    expect(AppsignalMock, :increment_counter, fn
      "worker.events.consumed", 11, %{} ->
        send(parent, {ref, :called})
        :ok
    end)

    :telemetry.execute([:worker, :events], %{consumed: 11}, %{})
    assert_receive {^ref, :called}

    TelemetryMetricsAppsignal.detach(metrics)
  end

  test "reporting gauge metrics" do
    # `Telemetry.Metrics.LastValue` maps to AppSignal's gauge metric
    metric = last_value("worker.queue.length")
    TelemetryMetricsAppsignal.attach([metric])

    parent = self()
    ref = make_ref()

    expect(AppsignalMock, :set_gauge, fn
      "worker.queue.length", 42, %{} ->
        send(parent, {ref, :called})
        :ok
    end)

    :telemetry.execute([:worker, :queue], %{length: 42}, %{})
    assert_receive {^ref, :called}

    TelemetryMetricsAppsignal.detach([metric])
  end

  test "reporting measurement metrics" do
    # `Telemetry.Metrics.Summary` maps to AppSignal's measurement metric
    metric = summary("db.query.duration")
    TelemetryMetricsAppsignal.attach([metric])

    parent = self()
    ref = make_ref()

    expect(AppsignalMock, :add_distribution_value, fn
      "db.query.duration", 99, %{} ->
        send(parent, {ref, :called})
        :ok
    end)

    :telemetry.execute([:db, :query], %{duration: 99}, %{})
    assert_receive {^ref, :called}

    TelemetryMetricsAppsignal.detach([metric])
  end

  test "converting time units" do
    metric = summary("db.query.duration", unit: {:native, :millisecond})
    TelemetryMetricsAppsignal.attach([metric])

    native_time = System.convert_time_unit(123, :millisecond, :native)
    parent = self()
    ref = make_ref()

    expect(AppsignalMock, :add_distribution_value, fn
      "db.query.duration", 123.0, %{} ->
        send(parent, {ref, :called})
        :ok
    end)

    :telemetry.execute([:db, :query], %{duration: native_time}, %{})
    assert_receive {^ref, :called}

    TelemetryMetricsAppsignal.detach([metric])
  end

  test "specifying metric tags" do
    metric = last_value("worker.queue.length", tags: [:queue, :host, :region])
    TelemetryMetricsAppsignal.attach([metric])

    parent = self()
    ref = make_ref()

    expect(AppsignalMock, :set_gauge, 4, fn
      "worker.queue.length", 42, tags ->
        send(parent, {ref, tags})
        :ok
    end)

    :telemetry.execute([:worker, :queue], %{length: 42}, %{
      queue: "mailer",
      host: "localhost"
    })

    tag_permutations = [
      %{queue: "mailer", host: "localhost"},
      %{queue: "mailer", host: "any"},
      %{queue: "any", host: "localhost"},
      %{queue: "any", host: "any"}
    ]

    for tags <- tag_permutations, do: assert_receive({^ref, ^tags})

    TelemetryMetricsAppsignal.detach([metric])
  end

  test "handling unsupported metrics" do
    metric = distribution("web.request.duration", buckets: [100, 200, 400])
    TelemetryMetricsAppsignal.attach([metric])
    :telemetry.execute([:web, :request], %{duration: 99}, %{})
    TelemetryMetricsAppsignal.detach([metric])
  end

  test "handling missing measurement" do
    metric = summary("db.query.duration")
    TelemetryMetricsAppsignal.attach([metric])
    :telemetry.execute([:db, :query], %{}, %{})
    TelemetryMetricsAppsignal.detach([metric])
  end
end
