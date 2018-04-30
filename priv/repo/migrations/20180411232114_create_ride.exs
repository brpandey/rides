defmodule Rides.Repo.Migrations.CreateRide do
  use Ecto.Migration

  def change do
    create table(:rides) do
      add(:driver_id, references(:persons, on_delete: :nothing), null: false)
      add(:passenger_id, references(:persons, on_delete: :nothing), null: false)

      timestamps()
    end

    # We create a unique index so that the association is always unique
    # E.g. we don't want duplicates of the same person (Akiko) and 
    # say passenger (Hirohito) more than once (atleast for this exercise)
    create(unique_index(:rides, [:driver_id, :passenger_id]))
  end
end
