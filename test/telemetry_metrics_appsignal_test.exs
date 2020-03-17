defmodule TelemetryMetricsAppsignalTest do
  use ExUnit.Case

  import Telemetry.Metrics

  alias Telemetry.Metrics.Counter
  alias Telemetry.Metrics.Distribution
  alias Telemetry.Metrics.LastValue
  alias Telemetry.Metrics.Sum
  alias Telemetry.Metrics.Summary

  @handler_prefix "telemetry_metrics_appsignal"

  test "attaching telemetry handlers" do
    metrics = [
      counter("web.request.count"),
      distribution("web.request.duration", buckets: [100, 200, 400]),
      last_value("worker.queue.length"),
      sum("worker.events.consumed"),
      summary("db.query.duration")
    ]

    TelemetryMetricsAppsignal.init(metrics)

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
  end
end
