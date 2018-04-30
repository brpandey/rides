defmodule Rides.Data do
  @moduledoc """
  Defines data fields returned from Provider API
  Primarily provides endpoint api data validation with no db persistence
  Used also to assist in deduplicating records via the checkpoint field
  """

  use Ecto.Schema
  require Logger
  import Ecto.Changeset
  alias Rides.Data

  @required_fields ~w(driver passenger car created_at)a
  @optional_fields ~w(extra checkpoint)a

  # We use an embedded schema since we are not persisting this 
  # but merely to validate the API endpoint data in an organized way

  embedded_schema do
    field(:driver, :string)
    field(:passenger, :string)
    field(:car, :string)
    field(:created_at, :integer)
    field(:extra, :binary, default: nil)
    # checkpoint is the last stale timestamp
    field(:checkpoint, :integer, default: 0)
  end

  @doc "Handles casting and validation for embedded_schema"
  def changeset(%Data{} = struct, params \\ :empty) do
    struct
    |> cast(params, List.flatten(@required_fields, @optional_fields))
    |> validate_required(@required_fields)
    |> validate_not_stale(:created_at, :checkpoint)
  end

  @doc """
  Provides enhanced changeset functionality with ability to specify data mapper functions.
  A before mapper function is applied before changeset validation
  """
  def changeset(%Data{} = struct, params, before_mapper)
      when is_nil(before_mapper) or is_function(before_mapper, 1) do
    params =
      case before_mapper do
        nil -> params
        _ -> before_mapper.(params)
      end

    changeset(struct, params)
  end

  @doc "Convenience routine to extra relevant fields in tuple format"
  def dump(%Data{} = struct) do
    {struct.driver, struct.passenger, struct.car, struct.created_at, struct.extra}
  end

  # Custom validation to ensure the record via the created_at field is not stale
  defp validate_not_stale(changeset, ca_field, cp_field) do
    case changeset.valid? do
      true ->
        timestamp = get_field(changeset, ca_field)
        checkpoint = get_field(changeset, cp_field)

        # Quick compare, the checkpoint is usually associated with a batch of records
        case timestamp > checkpoint do
          true ->
            changeset

          _ ->
            msg = "Stale value, #{timestamp} not greater than #{checkpoint}"
            # Logger.debug("Data changeset #{inspect(msg)}")
            add_error(changeset, :created_at, msg)
        end

      _ ->
        changeset
    end
  end
end
