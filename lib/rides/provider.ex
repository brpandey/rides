defmodule Rides.Provider do
  @moduledoc """
  Defines Provider behaviour
  Used by worker module and custom provider implementation modules

  Sample silly implementing module

  defmodule Gonzo do
  @behaviour Matches.Provider

    def new([]), do: IO.puts("Created Gonzo worker")
    def run(_, _sleep), do: IO.puts("I'm too busy speeding")
    def store(:ets, _data), do: :ok

  end
  """

  @type data :: [
          {driver :: binary(), passenger :: binary(), car :: binary(), created_at :: integer(),
           extra :: nil | binary()}
        ]

  @callback new(list) :: term
  @callback run(term, term) :: term

  # Note: Please define store, while noting 
  # it is convention for store to be called within run
  @callback store(term, data) :: term
end
