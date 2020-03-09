defmodule SpeedTest.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: PageRegistry},
      {SpeedTest.Page.Supervisor, name: PageSupervisor}
    ]

    env = System.get_env("SPEED_TEST_MOCKS")

    children =
      case Mix.env() do
        :test when env == "true" ->
          [
            {Plug.Cowboy, scheme: :http, plug: Test.Support.MockServer, options: [port: 8081]}
            | children
          ]

        _ ->
          children
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SpeedTest.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
