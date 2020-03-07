defmodule SpeedTest.Retry do
  defstruct timeout: :timer.seconds(3),
            interval: 100,
            max: round(:timer.seconds(3) / 100),
            attempts: 0

  def calc_max(%__MODULE__{} = retry) do
    round(retry.timeout / retry.interval)
  end
end
