defmodule AppsignalBehaviour do
  @callback add_distribution_value(String.t(), float() | integer(), map()) :: :ok
  @callback increment_counter(String.t(), number(), map()) :: :ok
  @callback set_gauge(String.t(), float() | integer(), map()) :: :ok
end

Hammox.defmock(AppsignalMock, for: AppsignalBehaviour)
