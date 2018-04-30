defmodule Rides.MixProject do
  use Mix.Project

  def project do
    [
      app: :rides,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :postgrex, :ecto, :retry],
      mod: {Rides, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 2.2.1"},
      {:postgrex, "~> 0.13"},
      {:quantum, ">= 2.2.0"},
      {:poison, "~> 2.0"},
      {:httpoison, "~> 0.11.0"},
      {:retry, "~> 0.8"},
      {:msgpax, "~> 2.0"}
    ]
  end

  defp aliases do
    [
      test: ["ecto.drop --quiet", "ecto.create --quiet", "ecto.migrate", "test"]
      # test: ["ecto.drop", "ecto.create", "ecto.migrate", "test"]
    ]
  end
end
