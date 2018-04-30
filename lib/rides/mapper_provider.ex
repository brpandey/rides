defmodule Rides.Mapper.Provider do
  @moduledoc """
  Mapper module for provider records table
  Provides validation and casting support as well as 
  convenience db methods to create and query
  """

  use Ecto.Schema
  import Ecto.Changeset
  #  import Ecto.Query

  alias Rides.Mapper.{Provider, Ride, RideProvider}
  alias Rides.Repo

  @required_fields ~w(name)a

  schema "providers" do
    field(:name, :string)
    many_to_many(:rides, Ride, join_through: RideProvider)

    timestamps()
  end

  @doc "Casts and validates requirements, ensures name is unique"
  def changeset(struct, params \\ :empty) do
    struct
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:name)
  end

  @doc "Creates provider record"
  def create(%{} = params), do: Provider.changeset(%Provider{}, params) |> Repo.insert()
  def create!(%{} = params), do: Provider.changeset(%Provider{}, params) |> Repo.insert!()
  def create!(name) when is_binary(name), do: create!(%{name: name})

  @doc "Fetch provider record by id"
  def fetch(:id, id) when is_integer(id), do: Provider |> Repo.get(id)

  @doc "Fetch provider record by name"
  def fetch(:name, name) when is_binary(name), do: Provider |> Repo.get_by(name: name)

  @doc "Returns the list of rides associated with the current provider, uses join table"
  def rides(%Provider{id: id}) do
    provider = Provider |> Repo.get(id)
    Repo.all(Ecto.assoc(provider, :rides))
  end
end
