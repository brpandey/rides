defmodule Rides.Mapper.Ride do
  @moduledoc """
  Mapper module for ride records table
  Provides validation and casting support as well as 
  convenience db methods to create and query
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Rides.Mapper.{Ride, Provider, RideProvider, Person}
  alias Rides.Repo

  @required_fields ~w(driver_id passenger_id)a

  schema "rides" do
    # foreign keys to person
    # many to many using join table rides_providers
    belongs_to(:driver, Person, foreign_key: :driver_id)
    belongs_to(:passenger, Person, foreign_key: :passenger_id)
    many_to_many(:providers, Provider, join_through: RideProvider)

    timestamps()
  end

  @doc """
  Creates ride given two persons.
  Check for duplicate person is at the changeset level 
  (Note: could easily be a guard clause)
  """
  def create(%Person{id: driver_id}, %Person{id: passenger_id}) do
    params = %{driver_id: driver_id, passenger_id: passenger_id}
    %Ride{} |> Ride.changeset(params) |> Repo.insert()
  end

  @doc "Creates ride as above but raises error if not successful"
  def create!(%Person{id: driver_id}, %Person{id: passenger_id}) do
    params = %{driver_id: driver_id, passenger_id: passenger_id}
    %Ride{} |> Ride.changeset(params) |> Repo.insert!()
  end

  @doc "Retrieves all rides with person as the driver"
  def fetch(:driver, person) when is_binary(person) do
    query =
      from(
        r in Ride,
        join: p in Person,
        on: p.id == r.driver_id,
        where: p.name == ^person
      )

    Repo.all(query)
  end

  @doc "Retrieves all ridees with person as the passenger"
  def fetch(:passenger, person) when is_binary(person) do
    query =
      from(
        r in Ride,
        join: p in Person,
        on: p.id == r.passenger_id,
        where: p.name == ^person
      )

    Repo.all(query)
  end

  @doc "Retrieves ride with specific driver and passenger string name"
  def fetch(:driver_passenger, driver, passenger)
      when is_binary(driver) and is_binary(passenger) do
    query =
      from(
        r in Ride,
        join: p1 in Person,
        join: p2 in Person,
        on: p1.id == r.driver_id,
        on: p2.id == r.passenger_id,
        where: p1.name == ^driver,
        where: p2.name == ^passenger
      )

    Repo.one(query)
  end

  @doc "Returns the person associated as the driver for the given ride"
  def driver(%Ride{id: id}) do
    ride = Ride |> Repo.get(id)
    Repo.one(Ecto.assoc(ride, :driver))
  end

  @doc "Returns the person associated as the passenger for the given ride"
  def passenger(%Ride{id: id}) do
    ride = Ride |> Repo.get(id)
    Repo.one(Ecto.assoc(ride, :passenger))
  end

  @doc "Returns the list of providers associated with the current ride, uses join table"
  def providers(%Ride{id: id}) do
    ride = Ride |> Repo.get(id)
    Repo.all(Ecto.assoc(ride, :providers))
  end

  @doc "Casts and validates params, ensures foreign key to person is enforced"

  def changeset(struct, params \\ :empty) do
    # Validations in order:
    # 1) validate required fields have right form
    # 2) must reference back to valid person
    # 3) must reference back to valid person
    # 4) the driver and passenger must be a unique combination
    # 5) passenger can't equal driver
    struct
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> assoc_constraint(:driver)
    |> assoc_constraint(:passenger)
    |> unique_constraint(:driver_id_passenger_id)
    |> validate_different_persons(:driver_id, :passenger_id)
  end

  # Custom changeset validation to ensure the two ride persons aren't the same!
  defp validate_different_persons(changeset, driver, passenger) do
    # Fetch field grabs field value either from the struct data or change
    {_, driver_value} = fetch_field(changeset, driver)
    {_, passenger_value} = fetch_field(changeset, passenger)

    if driver_value == passenger_value do
      add_error(
        changeset,
        passenger,
        "can't share value with #{driver}",
        info: "A person can't duplicate itself in a ride"
      )
    else
      changeset
    end
  end
end
