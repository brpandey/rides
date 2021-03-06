defmodule Rides.Mapper.RideProvider do
  @moduledoc """
  Mapper module for ride provider join schema table
  Provides validation and casting support as well as 
  convenience db methods to create and query
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Rides.Mapper.{Ride, RideProvider, Provider}
  alias Rides.Repo

  @required_fields ~w(ride_id provider_id created_at car)a
  @optional_fields ~w(extra)

  schema "rides_providers" do
    # foreign keys to team
    # many to many using join table rides_providers
    belongs_to(:ride, Ride)
    belongs_to(:provider, Provider)
    field(:created_at, :naive_datetime)
    field(:car, :string)
    # field(:created_at, :integer)
    field(:extra, :binary, default: nil)

    timestamps()
  end

  @doc "Creates ride provider given a ride and a provider"
  def create(%Ride{id: r_id}, %Provider{id: p_id}, car, created_at, extra)
      when is_integer(created_at) and is_binary(car) and (is_nil(extra) or is_binary(extra)) do
    params = %{ride_id: r_id, provider_id: p_id, car: car, created_at: created_at, extra: extra}

    %RideProvider{} |> RideProvider.changeset(params) |> Repo.insert()
  end

  @doc "Creates ride provider as above but raises error if not successful"
  def create!(%Ride{id: r_id}, %Provider{id: p_id}, car, created_at, extra)
      when is_integer(created_at) and is_binary(car) and (is_nil(extra) or is_binary(extra)) do
    params = %{ride_id: r_id, provider_id: p_id, car: car, created_at: created_at, extra: extra}

    %RideProvider{} |> RideProvider.changeset(params) |> Repo.insert!()
  end

  @doc "Retrieves ride provider with specific ride and provider"
  def fetch(:ride_provider, %Ride{id: rid}, %Provider{id: pid}) do
    query =
      from(
        rp in RideProvider,
        where: rp.ride_id == ^rid,
        where: rp.provider_id == ^pid
      )

    Repo.one(query)
  end

  @doc "Casts and validates requirements, ensures name is unique"
  def changeset(struct, params \\ :empty) do
    struct
    |> cast(cleanse(params), List.flatten(@required_fields, @optional_fields))
    |> validate_required(@required_fields)
    |> assoc_constraint(:ride)
    |> assoc_constraint(:provider)
    |> unique_constraint(:ride_id_provider_id)
  end

  # Helper routine to normalize created_at timestamp to more conventional 
  # timestamp format naive_datetime used by updated_at and inserted_at  
  # (assuming this doesn't provide confusion that it was generated by local db)

  # Note: It was quicker to implement the "cleanse" from integer to naive_datetime
  # this way then implementing a custom Ecto type as implementing the Ecto.Type
  # behavior was overkill having to implement 4 functions that weren't entirely relevant
  defp cleanse(%{created_at: ca} = params) when is_integer(ca) do
    case DateTime.from_unix(ca) do
      {:ok, dt} ->
        ca = DateTime.to_string(dt) |> NaiveDateTime.from_iso8601!()
        Map.put(params, :created_at, ca)

      {:error, _} ->
        params
    end
  end

  defp cleanse(%{} = params), do: params
end
