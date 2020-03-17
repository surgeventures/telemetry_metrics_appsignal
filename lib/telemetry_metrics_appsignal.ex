defmodule TelemetryMetricsAppsignal do
  require Logger

  alias Telemetry.Metrics.Counter
  alias Telemetry.Metrics.Distribution
  alias Telemetry.Metrics.LastValue
  alias Telemetry.Metrics.Sum
  alias Telemetry.Metrics.Summary

  @handler_prefix "telemetry_metrics_appsignal"

  @type metric ::
          Counter.t()
          | Distribution.t()
          | LastValue.t()
          | Sum.t()
          | Summary.t()

  @spec init([metric]) :: no_return()
  def init(metrics) do
    metrics
    |> Enum.group_by(& &1.event_name)
    |> Enum.each(fn {event_name, metrics} ->
      handler_id = Enum.join([@handler_prefix | event_name], "_")

      :telemetry.attach(handler_id, event_name, &handle_event/4, metrics: metrics)
    end)
  end

  defp handle_event(_, _, _, _) do
    nil
  end
end
