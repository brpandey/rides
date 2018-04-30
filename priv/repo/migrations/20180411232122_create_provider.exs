defmodule Rides.Repo.Migrations.CreateProvider do
  use Ecto.Migration

  def change do
    create table(:providers) do
      add(:name, :string, null: false)

      timestamps()
    end

    # Create database constraint 
    # Ensure we don't have multiple provider records with the same name
    # a single name corresponds to a single provider

    create(unique_index(:providers, [:name]))
  end
end
