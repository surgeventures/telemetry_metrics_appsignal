defmodule TelemetryMetricsAppsignalTest do
  use ExUnit.Case

  import ExUnit.CaptureLog
  import Telemetry.Metrics
  import Hammox

  alias Telemetry.Metrics.Counter
  alias Telemetry.Metrics.Distribution
  alias Telemetry.Metrics.LastValue
  alias Telemetry.Metrics.Sum
  alias Telemetry.Metrics.Summary

  @moduletag capture_log: true

  setup :verify_on_exit!

  test "registering a name with the genserver" do
    pid = start_reporter(metrics: [], name: __MODULE__)
    assert Process.whereis(__MODULE__) == pid
  end

  test "not providing metrics" do
    start_reporter([])
    attached_handlers = :telemetry.list_handlers([])
    actual_event_metrics = fetch_event_metrics(attached_handlers)

    assert actual_event_metrics == %{}

    stop_supervised!(TelemetryMetricsAppsignal)

    attached_handlers = :telemetry.list_handlers([])

    assert attached_handlers == []
  end

  test "attaching and detaching telemetry handlers" do
    metrics = [
      counter("web.request.count"),
      distribution("web.request.duration", buckets: [100, 200, 400]),
      last_value("worker.queue.length"),
      sum("worker.events.consumed"),
      summary("db.query.duration")
    ]

    start_reporter(metrics: metrics)

    attached_handlers = :telemetry.list_handlers([])

    event_metrics = %{
      [:web, :request] => [Counter, Distribution],
      [:worker, :queue] => [LastValue],
      [:worker, :events] => [Sum],
      [:db, :query] => [Summary]
    }

    actual_event_metrics = fetch_event_metrics(attached_handlers)
    assert actual_event_metrics == event_metrics

    stop_supervised!(TelemetryMetricsAppsignal)
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

    start_reporter(metrics: metrics)

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
  end

  test "reporting gauge metrics" do
    # `Telemetry.Metrics.LastValue` maps to AppSignal's gauge metric
    metric = last_value("worker.queue.length")
    start_reporter(metrics: [metric])

    parent = self()
    ref = make_ref()

    expect(AppsignalMock, :set_gauge, fn
      "worker.queue.length", 42, %{} ->
        send(parent, {ref, :called})
        :ok
    end)

    :telemetry.execute([:worker, :queue], %{length: 42}, %{})
    assert_receive {^ref, :called}
  end

  test "reporting measurement metrics" do
    # `Telemetry.Metrics.Summary` maps to AppSignal's measurement metric
    metric = summary("db.query.duration")
    start_reporter(metrics: [metric])

    parent = self()
    ref = make_ref()

    expect(AppsignalMock, :add_distribution_value, fn
      "db.query.duration", 99, %{} ->
        send(parent, {ref, :called})
        :ok
    end)

    :telemetry.execute([:db, :query], %{duration: 99}, %{})
    assert_receive {^ref, :called}
  end

  test "reporting calculated metrics with unary functions" do
    # `Telemetry.Metrics.Summary` maps to AppSignal's measurement metric
    metric =
      summary("db.query.duration_multiplied",
        measurement: fn measurements ->
          measurements.duration * 10
        end
      )

    start_reporter(metrics: [metric])

    parent = self()
    ref = make_ref()

    expect(AppsignalMock, :add_distribution_value, fn
      "db.query.foo", 990, %{} ->
        send(parent, {ref, :called})
        :ok
    end)

    :telemetry.execute([:db, :query], %{duration: 99}, %{})
    assert_receive {^ref, :called}
  end

  test "reporting calculated metrics with binary functions" do
    # `Telemetry.Metrics.Summary` maps to AppSignal's measurement metric
    metric =
      summary("db.query.duration_multiplied",
        measurement: fn measurements, metadata ->
          measurements.duration * metadata.multiplier
        end
      )

    start_reporter(metrics: [metric])

    parent = self()
    ref = make_ref()

    expect(AppsignalMock, :add_distribution_value, fn
      "db.query.duration_multiplied", 198, %{} ->
        send(parent, {ref, :called})
        :ok
    end)

    :telemetry.execute([:db, :query], %{duration: 99}, %{multiplier: 2})
    assert_receive {^ref, :called}
  end

  test "converting time units" do
    metric = summary("db.query.duration", unit: {:native, :millisecond})
    start_reporter(metrics: [metric])

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
  end

  test "specifying metric tags" do
    metric = last_value("worker.queue.length", tags: [:queue, :host, :region])
    start_reporter(metrics: [metric])

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
  end

  test "specifying metric tag values" do
    metric = last_value("worker.queue.length", tags: [:value], tag_values: &get_and_put_value/1)
    start_reporter(metrics: [metric])

    parent = self()
    ref = make_ref()

    expect(AppsignalMock, :set_gauge, 1, fn
      "worker.queue.length", 42, tags ->
        send(parent, {ref, tags})
        :ok
    end)

    :telemetry.execute([:worker, :queue], %{length: 42}, %{})

    assert_receive({^ref, %{value: "value"}})
  end

  test "handling unsupported metrics" do
    metric = distribution("web.request.duration", buckets: [100, 200, 400])
    start_reporter(metrics: [metric])
    :telemetry.execute([:web, :request], %{duration: 99}, %{})
  end

  test "handling missing measurement" do
    metric = summary("db.query.duration")
    start_reporter(metrics: [metric])

    assert capture_log(fn ->
             :telemetry.execute([:db, :query], %{}, %{})
           end) == ""
  end

  defp start_reporter(opts) do
    start_supervised!({TelemetryMetricsAppsignal, opts})
  end

  defp get_and_put_value(metadata) do
    Map.put_new(metadata, :value, "value")
  end

  defp fetch_event_metrics(attached_handlers) do
    Enum.reduce(attached_handlers, %{}, fn handler, metrics_acc ->
      handler_metrics = handler.config[:metrics]
      event_name = List.first(handler.config[:metrics]).event_name
      modules = Enum.map(handler_metrics, & &1.__struct__())
      Map.put(metrics_acc, event_name, modules)
    end)
  end
end
