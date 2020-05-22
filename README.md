# TelemetryMetricsAppsignal

[![CircleCI](https://circleci.com/gh/surgeventures/telemetry_metrics_appsignal.svg?style=svg)](https://circleci.com/gh/surgeventures/telemetry_metrics_appsignal)
[![Hex pm](http://img.shields.io/hexpm/v/telemetry_metrics_appsignal.svg?style=flat)](https://hex.pm/packages/telemetry_metrics_appsignal)

A `Telemetry.Metrics` reporter that pushes metrics to AppSignal. Requires [the AppSignal library](https://hexdocs.pm/appsignal) to be installed and configured.

## Installation

Add `telemetry_metrics_appsignal` to your `mix.exs` file:

```elixir
def deps do
  [
    {:telemetry_metrics_appsignal, "~> 0.1.1"}
  ]
end
```

See the documentation on [Hexdocs](https://hexdocs.pm/telemetry_metrics_appsignal/TelemetryMetricsAppsignal.html) for more information.
