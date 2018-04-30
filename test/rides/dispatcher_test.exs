defmodule Rides.DispatcherTest do
  use ExUnit.Case

  require Logger
  alias Rides.{Dispatcher, Manifest}

  test "spawned tasks are in different pids" do
    # test that the spawned methods are in different pids

    no_stagger = [0, 0]

    providers = Manifest.load(providers())

    assert [{Rides.DispatcherTest.Gonzo, :ok}, {Rides.DispatcherTest.Fonzee, :ok}] == providers

    IO.puts("self is #{inspect(self())}")

    Dispatcher.run(providers, no_stagger)
  end

  def providers() do
    %{
      :wakawaka => %{
        :active => true,
        :format => {:custom, Rides.DispatcherTest.Fonzee},
        :key => "Fonzee Bear"
      },
      :gonzo => %{
        :active => true,
        :format => {:custom, Rides.DispatcherTest.Gonzo},
        :key => "Gonzo"
      }
    }
  end

  defmodule Gonzo do
    @behaviour Rides.Provider

    def new([]), do: IO.puts("Created Gonzo worker")

    def run(_, _sleep) do
      IO.puts("I'm too busy speeding! #{inspect(self())}")
    end

    def store(:ets, _data), do: :ok
  end

  defmodule Fonzee do
    @behaviour Rides.Provider

    def new([]), do: IO.puts("Created Fonzee worker")

    def run(_, _sleep) do
      IO.puts("Fonzee eating instead. Me busy. Waka waka! #{inspect(self())}")
    end

    def store(:ets, _data), do: :ok
  end
end
