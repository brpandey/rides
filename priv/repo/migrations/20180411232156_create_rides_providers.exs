defmodule Rides.Repo.Migrations.CreateRidesProviders do
  use Ecto.Migration

  def change do
    create table(:rides_providers) do
      add(:ride_id, references(:rides), null: false)
      add(:provider_id, references(:providers), null: false)
      add(:created_at, :naive_datetime, null: false)
      add(:car, :string, null: false)
      add(:extra, :binary, null: true)

      timestamps()
    end

    # We create a unique index so that the association is always unique
    # E.g. we don't want copies of the same ride_id 3 and provider_id 4 
    # more than once
    create(unique_index(:rides_providers, [:ride_id, :provider_id]))
  end
end
