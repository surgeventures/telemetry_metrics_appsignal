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

  @type option :: {:namespace, String.t()}

  @spec attach([metric], keyword(option)) :: no_return()
  def attach(metrics, opts \\ []) do
    namespace = Keyword.get(opts, :namespace)
    handler_prefix = prepare_handler_prefix(namespace)

    metrics
    |> Enum.group_by(& &1.event_name)
    |> Enum.each(fn {event_name, metrics} ->
      handler_id = Enum.join(handler_prefix ++ event_name, "_")

      :telemetry.attach(handler_id, event_name, &handle_event/4, metrics: metrics)
    end)
  end

  @spec detach([metric], keyword(option)) :: no_return()
  def detach(metrics, opts \\ []) do
    namespace = Keyword.get(opts, :namespace)
    handler_prefix = prepare_handler_prefix(namespace)

    metrics
    |> Enum.map(& &1.event_name)
    |> Enum.each(fn event_name ->
      handler_id = Enum.join(handler_prefix ++ event_name, "_")
      :telemetry.detach(handler_id)
    end)
  end

  defp handle_event(_event_name, measurements, metadata, config) do
    metrics = Keyword.get(config, :metrics, [])

    Enum.each(metrics, fn metric ->
      value = prepare_metric_value(metric.measurement, measurements)
      tags = prepare_metric_tags(metric.tags, metadata)
      send_metric(metric, value, tags)
    end)
  end

  defp prepare_handler_prefix(namespace) do
    [@handler_prefix, namespace] |> Enum.reject(&is_nil/1)
  end

  defp prepare_metric_value(measurement, measurements)

  defp prepare_metric_value(convert, measurements) when is_function(convert) do
    convert.(measurements)
  end

  defp prepare_metric_value(measurement, measurements)
       when is_map_key(measurements, measurement) do
    measurements[measurement]
  end

  defp prepare_metric_value(_, _), do: nil

  defp prepare_metric_tags(tags, metadata) do
    Map.take(metadata, tags)
  end

  defp send_metric(%Counter{} = metric, _value, tags) do
    call_appsignal(:increment_counter, metric.name, 1, tags)
  end

  defp send_metric(%Summary{} = metric, value, tags) do
    call_appsignal(
      :add_distribution_value,
      metric.name,
      value,
      tags
    )
  end

  defp send_metric(%LastValue{} = metric, value, tags) do
    call_appsignal(
      :set_gauge,
      metric.name,
      value,
      tags
    )
  end

  defp send_metric(%Sum{} = metric, value, tags) do
    call_appsignal(
      :increment_counter,
      metric.name,
      value,
      tags
    )
  end

  defp send_metric(metric, _measurements, _tags) do
    Logger.warn("Ignoring unsupported metric #{inspect(metric)}")
  end

  defp call_appsignal(function_name, key, value, tags) when is_list(key) do
    call_appsignal(function_name, Enum.join(key, "."), value, tags)
  end

  defp call_appsignal(function_name, key, value, tags)
       when is_binary(key) and is_number(value) and is_map(tags) do
    tags
    |> tag_permutations()
    |> Enum.each(fn tags_permutation ->
      apply(@appsignal, function_name, [key, value, tags_permutation])
    end)
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

  defp tag_permutations(map) when map == %{}, do: [%{}]

  defp tag_permutations(tags) do
    for {tag_name, tag_value} <- tags,
        value_permutation <- [tag_value, "any"],
        rest <- tag_permutations(Map.drop(tags, [tag_name])) do
      Map.put(rest, tag_name, value_permutation)
    end
    |> Enum.uniq()
  end
end
