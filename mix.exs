defmodule TelemetryMetricsAppsignal.MixProject do
  use Mix.Project

  def project do
    [
      app: :telemetry_metrics_appsignal,
      version: "0.1.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:appsignal, "~> 1.12"},
      {:hammox, "~> 0.2", only: :test},
      {:jason, "~> 1.1"},
      {:telemetry, "~> 0.4"},
      {:telemetry_metrics, "~> 0.4"}
    ]
  end
end
