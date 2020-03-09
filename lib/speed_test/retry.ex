defmodule SpeedTest.Retry do
  @moduledoc """
  Wrapper around retries and calculating how many retries to run.

  ### Examples
      iex> %SpeedTest.Retry{timeout: :timer.seconds(2)}
      iex> %SpeedTest.Retry{timeout: :timer.seconds(10), interval: :timer.seconds(1)}
  """
  defstruct timeout: :timer.seconds(3),
            interval: 100,
            attempts: 0

  @spec calc_max(Retry.t()) :: integer
  @doc ~S"""
  Calculates the max number of interations to
  execute the retry on.
  """
  def calc_max(%__MODULE__{} = retry) do
    round(retry.timeout / retry.interval)
  end
end
