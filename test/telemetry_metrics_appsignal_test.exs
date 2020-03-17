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

  test "attaching telemetry handlers" do
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
  end

  test "reporting counter metrics" do
    # `Telemetry.Metrics.Counter` and `Telemetry.Metrics.Sum`
    # both map to AppSignal's counter metric
    metrics = [
      counter("web.request.count"),
      sum("worker.events.consumed")
    ]

    TelemetryMetricsAppsignal.attach(metrics)

    expect(AppsignalMock, :increment_counter, fn key, value, tags ->
      assert key == "web.request.count"
      assert value == 1
      assert tags == %{controller: "HomeController", action: "index"}
      :ok
    end)

    :telemetry.execute([:web, :request], %{}, %{controller: "HomeController", action: "index"})

    # Measurements should be ignored for counter metric
    expect(AppsignalMock, :increment_counter, fn key, value, _tags ->
      assert key == "web.request.count"
      assert value == 1
      :ok
    end)

    :telemetry.execute([:web, :request], %{count: 5}, %{})

    expect(AppsignalMock, :increment_counter, fn key, value, tags ->
      assert key == "worker.events.consumed"
      assert value == 11
      assert tags == %{queue: "payments"}
      :ok
    end)

    :telemetry.execute([:worker, :events], %{consumed: 11}, %{queue: "payments"})

    TelemetryMetricsAppsignal.detach(metrics)
  end

  test "reporting gauge metrics" do
    # `Telemetry.Metrics.LastValue` maps to AppSignal's gauge metric
    metric = last_value("worker.queue.length")
    TelemetryMetricsAppsignal.attach([metric])

    expect(AppsignalMock, :set_gauge, fn key, value, tags ->
      assert key == "worker.queue.length"
      assert value == 42
      assert tags == %{queue: "mailing"}
      :ok
    end)

    :telemetry.execute([:worker, :queue], %{length: 42}, %{queue: "mailing"})

    TelemetryMetricsAppsignal.detach([metric])
  end

  test "reporting measurement metrics" do
    # `Telemetry.Metrics.Summary` maps to AppSignal's measurement metric
    metric = summary("db.query.duration")
    TelemetryMetricsAppsignal.attach([metric])

    expect(AppsignalMock, :add_distribution_value, fn key, value, tags ->
      assert key == "db.query.duration"
      assert value == 99
      assert tags == %{statement: "SELECT"}
      :ok
    end)

    :telemetry.execute([:db, :query], %{duration: 99}, %{statement: "SELECT"})

    TelemetryMetricsAppsignal.detach([metric])
  end

  test "handles unsupported metrics" do
    metric = distribution("web.request.duration", buckets: [100, 200, 400])
    TelemetryMetricsAppsignal.attach([metric])
    :telemetry.execute([:web, :request], %{duration: 99}, %{})
    TelemetryMetricsAppsignal.detach([metric])
  end
end
