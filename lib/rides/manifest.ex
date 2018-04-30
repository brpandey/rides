defmodule Rides.Manifest do
  @moduledoc """
  Implements client-facing functions for dealing with Manifest

  Manifest is used to provide domain specific metadata to eventually instantiate
  a Worker process
  """

  require Logger

  alias Rides.Manifest.Schema
  alias Rides.Worker

  @providers Application.get_env(:rides, :providers_manifest, %{})

  @doc "Validate and then load providers into a usable, actionable form"
  def load(), do: load(@providers)

  def load(%{} = m) do
    # Enlist help of schema to ensure manifest is well-formed
    case Schema.validate(m) do
      :ok ->
        # Since validation is successful,
        # Instantiate these provider workers using their manifest metadata
        # Returning a list of non-nil provider worker structs

        Enum.map(m, fn {_k, v} ->
          case Schema.entry(v) do
            nil -> nil
            {:ok, {:module, module}} -> {module, Kernel.apply(module, :new, [[]])}
            {:ok, args} -> Worker.new(args)
          end
        end)
        |> Enum.reject(&Kernel.is_nil(&1))

      msg ->
        Logger.error("Unable to load providers list, msg: #{inspect(msg)}")
        []
    end
  end

  _ = """
  Slice of manifest map
    %{
      # Specify the provider manifest entry for Kamakurashares
      :kamakura => %{
        :active => true,
        :format => :manifest,
        # Key to store provider id alongside fetched ride data tuple
        :key => "Kamakurashares",
        ...
      %},
    %}
  """

  @doc "Retrieve key values from provider manifest entries"
  def keys(), do: keys(@providers)

  def keys(%{} = m) do
    Enum.map(m, fn {_k, %{} = v} ->
      Map.get(v, :key)
    end)
  end
end
