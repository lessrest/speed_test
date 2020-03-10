defmodule SpeedTest.MixProject do
  use Mix.Project

  def project do
    [
      app: :speed_test,
      description: "Package that helps automate browser testing, similar to puppeteer.",
      version: "0.1.1",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: [main: "usage", extras: ["README.md", "guides/usage.md"]]
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
      {:plug, "~> 1.8.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.2", only: [:dev, :test], runtime: false}
    ]
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/nathanjohnson320/speed_test"}
    ]
  end
end
