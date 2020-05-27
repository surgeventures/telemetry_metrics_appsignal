defmodule TelemetryMetricsAppsignal do
  @moduledoc """
  AppSignal Reporter for [`Telemetry.Metrics`](https://github.com/beam-telemetry/telemetry_metrics) definitions.

  This reporter is useful for getting [custom metrics](https://docs.appsignal.com/metrics/custom.html)
  into AppSignal from your application. These custom metrics are especially
  useful for building custom dashboards.

  To use the reporter, first define a list of metrics as shown here:

      def metrics, do:
        [
          summary("phoenix.endpoint.stop.duration"),
          last_value("vm.memory.total"),
          counter("my_app.my_server.call.exception")
        ]

  It's recommended to start TelemetryMetricsAppsignal under a supervision tree,
  either in your main application or as recommended [here](https://hexdocs.pm/phoenix/telemetry.html#the-telemetry-supervisor)
  if using Phoenix:

      {TelemetryMetricsAppsignal, [metrics: metrics()]}

  Putting that altogether, your configuration could look something like this:

      def start_link(_arg) do
        children = [
          {TelemetryMetricsAppsignal, [metrics: metrics()]},
          ...
        ]
        Supervisor.init(children, strategy: :one_for_one)
      end

      defp metrics, do:
        [
          summary("phoenix.endpoint.stop.duration"),
          last_value("vm.memory.total"),
          counter("my_app.my_server.call.exception")
        ]

    Optionally you can register a name:

        {TelemetryMetricsAppsignal,
          [metrics: metrics(), name: MyTelemetryMetricsAppsignal]}

  The following table shows how `Telemetry.Metrics` metrics map to [AppSignal
  metrics](https://docs.appsignal.com/metrics/custom.html#metric-types):

  | Telemetry.Metrics     | AppSignal |
  |-----------------------|-----------|
  | `last_value`          | `gauge` |
  | `counter`             | `counter` |
  | `sum`                 | `counter`, increased by the provided value |
  | `summary`             | `measurement` |
  | `distribution`        | Not supported |
  """
  use GenServer
  require Logger

  alias Telemetry.Metrics.Counter
  alias Telemetry.Metrics.Distribution
  alias Telemetry.Metrics.LastValue
  alias Telemetry.Metrics.Sum
  alias Telemetry.Metrics.Summary

  @appsignal Application.compile_env(:telemetry_metrics_appsignal, :appsignal, Appsignal)

  @type metric ::
          Counter.t()
          | Distribution.t()
          | LastValue.t()
          | Sum.t()
          | Summary.t()

  @type option :: {:metrics, [metric]} | {:name, GenServer.name()}

  @spec start_link([option]) :: GenServer.on_start()
  def start_link(opts) do
    server_opts = Keyword.take(opts, [:name])
    metrics = Keyword.get(opts, :metrics, [])
    GenServer.start_link(__MODULE__, metrics, server_opts)
  end

  @impl true
  @spec init([metric]) :: {:ok, [[atom]]}
  def init(metrics) do
    Process.flag(:trap_exit, true)
    groups = Enum.group_by(metrics, & &1.event_name)

    for {event, metrics} <- groups do
      id = {__MODULE__, event, self()}
      :telemetry.attach(id, event, &handle_event/4, metrics: metrics)
    end

    {:ok, Map.keys(groups)}
  end

  @impl true
  def terminate(_, events) do
    for event <- events do
      :telemetry.detach({__MODULE__, event, self()})
    end

    :ok
  end

  defp handle_event(_event_name, measurements, metadata, config) do
    metrics = Keyword.get(config, :metrics, [])

    Enum.each(metrics, fn metric ->
      if value = prepare_metric_value(metric, measurements) do
        tags = prepare_metric_tags(metric, metadata)
        send_metric(metric, value, tags)
      end
    end)
  end

  defp prepare_metric_value(metric, measurements)

  defp prepare_metric_value(%Counter{}, _measurements), do: 1

  defp prepare_metric_value(%{measurement: convert}, measurements) when is_function(convert) do
    convert.(measurements)
  end

  defp prepare_metric_value(%{measurement: measurement}, measurements)
       when is_map_key(measurements, measurement) do
    measurements[measurement]
  end

  defp prepare_metric_value(_, _), do: nil

  defp prepare_metric_tags(metric, metadata) do
    tag_values = metric.tag_values.(metadata)
    Map.take(tag_values, metric.tags)
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
