# TelemetryMetricsAppsignal

[![CircleCI](https://circleci.com/gh/surgeventures/telemetry_metrics_appsignal.svg?style=svg)](https://circleci.com/gh/surgeventures/telemetry_metrics_appsignal)

A `Telemetry.Metrics` reporter that pushes metrics to AppSignal. Requires [the AppSignal library](https://hexdocs.pm/appsignal) to be installed and configured.

## Installation

Add `telemetry_metrics_appsignal` to your `mix.exs` file:

```elixir
def deps do
  [
    {:telemetry_metrics_appsignal, "~> 0.1.0"}
  ]
end
```

## Usage

Once you've configured [the AppSignal library](https://hexdocs.pm/appsignal), you can define the metrics you want to collect:

```elixir
defp metrics do
  [
    [
      counter("web.request.count"),
      last_value("worker.queue.length"),
      sum("worker.events.consumed"),
      summary("db.query.duration")
    ]
  ]
end
```

Then attach them to the AppSignal reporter, probably in your `application.ex` file:

```elixir
TelemetryMetricsReporter.attach(metrics())
```
