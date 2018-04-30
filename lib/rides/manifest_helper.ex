defmodule Rides.Manifest.Helper do
  @moduledoc """
  Define functions that will be used in the rides manifest file
  Allows these functions to be reference in MFA format from manifest
  """

  @doc "First helper routine used by kamakura provider"
  def split_first(value) when is_binary(value) do
    String.split(value, " - ") |> List.first()
  end

  @doc "Second helper routine used by kamakura provider"
  def split_last(value) when is_binary(value) do
    String.split(value, " - ") |> List.last()
  end
end
