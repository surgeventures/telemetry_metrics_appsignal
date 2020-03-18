defmodule AppsignalBehaviour do
  @callback add_distribution_value(String.t(), number(), map()) :: :ok
  @callback increment_counter(String.t(), number(), map()) :: :ok
  @callback set_gauge(String.t(), number(), map()) :: :ok
end

Hammox.defmock(AppsignalMock, for: AppsignalBehaviour)
