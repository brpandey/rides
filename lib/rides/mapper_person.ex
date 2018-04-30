defmodule Rides.Mapper.Person do
  @moduledoc """
  Mapper module for person records table
  Provides validation and casting support as well as 
  convenience db methods to create and query
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Rides.Mapper.{Person, Ride}
  alias Rides.Repo

  @required_fields ~w(name)a

  schema "persons" do
    field(:name, :string)

    has_many(:drivers, Ride, foreign_key: :driver_id)
    has_many(:passengers, Ride, foreign_key: :passenger_id)

    timestamps()
  end

  @doc "Casts and validates requirements, ensures name is unique"
  def changeset(struct, params \\ :empty) do
    struct
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:name)
  end

  @doc "Creates person record"
  def create(%{} = params), do: Person.changeset(%Person{}, params) |> Repo.insert()
  def create!(%{} = params), do: Person.changeset(%Person{}, params) |> Repo.insert!()
  def create!(name) when is_binary(name), do: create!(%{name: name})

  @doc "Fetch person record by id"
  def fetch(:id, id) when is_integer(id), do: Person |> Repo.get(id)

  @doc "Fetch person record by name"
  def fetch(:name, name) when is_binary(name), do: Person |> Repo.get_by(name: name)

  @doc "Returns all rides associated with person"
  def rides(%Person{id: id}) do
    %Person{drivers: d} = Repo.get(Person, id) |> Repo.preload(:drivers)
    %Person{passengers: p} = Repo.get(Person, id) |> Repo.preload(:passengers)
    List.flatten(d, p)
  end

  @doc "Returns all driver rides for person"
  def rides_driver(%Person{id: id}) do
    %Person{drivers: d} = Repo.get(Person, id) |> Repo.preload(:drivers)
    d
  end

  @doc "Returns all passenger rides for person"
  def rides_passenger(%Person{id: id}) do
    %Person{passengers: p} = Repo.get(Person, id) |> Repo.preload(:passengers)
    p
  end
end
