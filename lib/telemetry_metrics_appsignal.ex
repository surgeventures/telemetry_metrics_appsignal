defmodule TelemetryMetricsAppsignal do
  require Logger

  alias Telemetry.Metrics.Counter
  alias Telemetry.Metrics.Distribution
  alias Telemetry.Metrics.LastValue
  alias Telemetry.Metrics.Sum
  alias Telemetry.Metrics.Summary

  @appsignal Application.compile_env(:telemetry_metrics_appsignal, :appsignal, Appsignal)
  @handler_prefix "telemetry_metrics_appsignal"

  @type metric ::
          Counter.t()
          | Distribution.t()
          | LastValue.t()
          | Sum.t()
          | Summary.t()

  @spec attach([metric]) :: no_return()
  def attach(metrics) do
    metrics
    |> Enum.group_by(& &1.event_name)
    |> Enum.each(fn {event_name, metrics} ->
      handler_id = Enum.join([@handler_prefix | event_name], "_")

      :telemetry.attach(handler_id, event_name, &handle_event/4, metrics: metrics)
    end)
  end

  @spec detach([metric]) :: no_return()
  def detach(metrics) do
    metrics
    |> Enum.map(& &1.event_name)
    |> Enum.each(fn event_name ->
      handler_id = Enum.join([@handler_prefix | event_name], "_")
      :telemetry.detach(handler_id)
    end)
  end

  defp handle_event(_event_name, measurements, metadata, config) do
    metrics = Keyword.get(config, :metrics, [])

    Enum.each(metrics, fn metric ->
      send_metric(metric, measurements, metadata)
    end)
  end

  defp send_metric(%Counter{} = metric, _measurements, metadata) do
    call_appsignal(:increment_counter, metric.name, 1, metadata)
  end

  defp send_metric(%Summary{} = metric, measurements, metadata) do
    call_appsignal(
      :add_distribution_value,
      metric.name,
      measurements[metric.measurement],
      metadata
    )
  end

  defp send_metric(%LastValue{} = metric, measurements, metadata) do
    call_appsignal(
      :set_gauge,
      metric.name,
      measurements[metric.measurement],
      metadata
    )
  end

  defp send_metric(%Sum{} = metric, measurements, metadata) do
    call_appsignal(
      :increment_counter,
      metric.name,
      measurements[metric.measurement],
      metadata
    )
  end

  defp send_metric(metric, _measurements, _metadata) do
    Logger.warn("Ignoring unsupported metric #{inspect(metric)}")
  end

  defp call_appsignal(function_name, key, value, tags) when is_list(key) do
    call_appsignal(function_name, Enum.join(key, "."), value, tags)
  end

  defp call_appsignal(function_name, key, value, tags)
       when is_binary(key) and is_number(value) and is_map(tags) do
    apply(@appsignal, function_name, [key, value, tags])
  end

  defp call_appsignal(function_name, key, value, tags) do
    Logger.warn("""
    Attempted to send metrics invalid with AppSignal library: \
    #{inspect(function_name)}(\
    #{inspect(key)}, \
    #{inspect(value)}, \
    #{inspect(tags)}\
    )
    """)
  end
end
