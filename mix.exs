defmodule SpeedTest.MixProject do
  use Mix.Project

  def project do
    [
      app: :speed_test,
      description: "Package that helps automate browser testing, similar to puppeteer.",
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/nathanjohnson320/speed_test"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {SpeedTest.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixir_uuid, "~> 1.2"},
      {:chroxy, "~> 0.6.3"},
      {:chrome_remote_interface, "~> 0.3.0"},
      {:plug_cowboy, "~> 2.0.1"},
      {:plug, "~> 1.8.0"}
    ]
  end
end
