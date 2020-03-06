defmodule SpeedTest.Retry do
  defstruct timeout: :timer.seconds(3),
            interval: 100,
            max: round(:timer.seconds(3) / 100),
            attempts: 0
end
