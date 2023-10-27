# TelemetryMetricsAppsignal

[![GitHub Workflow Status (branch)](https://img.shields.io/github/actions/workflow/status/surgeventures/telemetry_metrics_appsignal/test.yml?branch=main)](https://github.com/surgeventures/telemetry_metrics_appsignal/actions/workflows/test.yml?query=branch%3Amain)
[![Hex pm](http://img.shields.io/hexpm/v/telemetry_metrics_appsignal)](https://hex.pm/packages/telemetry_metrics_appsignal)

A `Telemetry.Metrics` reporter that pushes metrics to AppSignal. Requires [the AppSignal library](https://hexdocs.pm/appsignal) to be installed and configured.

## Installation

Add `telemetry_metrics_appsignal` to your `mix.exs` file:

```elixir
def deps do
  [
    {:telemetry_metrics_appsignal, "~> 1.0"}
  ]
end
```

See the documentation on [Hexdocs](https://hexdocs.pm/telemetry_metrics_appsignal/TelemetryMetricsAppsignal.html) for more information.
