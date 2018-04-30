defmodule Rides.Repo.Migrations.CreatePerson do
  use Ecto.Migration

  def change do
    create table(:persons) do
      add(:name, :string, null: false)

      timestamps()
    end

    # Create database constraint 
    # Ensure we don't have multiple team records with the same name
    # a single name corresponds to a single team

    create(unique_index(:persons, [:name]))
  end
end
