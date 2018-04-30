defmodule Rides.DataTest do
  # no side effects, so async true is fine
  use ExUnit.Case, async: true

  alias Rides.Data

  # valid attributes with nil for extra
  @valid_attrs1 %{
    "driver" => "Kengo",
    "passenger" => "Masahisa",
    "car" => "Toyota Avalon",
    "created_at" => 1_522_883_972,
    "extra" => nil
  }

  # valid attributes with serialized lob "extra" field
  @valid_attrs2 %{
    "driver" => "Yuki",
    "passenger" => "Masahisa",
    "car" => "Toyota Avalon",
    "created_at" => 1_522_883_972,
    "extra" => Msgpax.pack!(%{sponsor: "The Muppets"}, iodata: false)
  }

  # Wrong value type for driver and extra
  @invalid_attrs1 %{
    "driver" => :did_not_bring_drivers_license,
    "passenger" => "Masahisa",
    "car" => "Toyota Avalon",
    "created_at" => 1_522_883_972,
    "extra" => "a flock of seagulls"
  }

  # Field name misspelling, wrong value type for created_at
  @invalid_attrs1 %{
    "diver" => "Yuki",
    "passenger" => "Masahisa",
    "car" => "Toyota Avalon",
    "created_at" => "yesterday",
    "extra" => nil
  }

  # Checkpoint value indicates stale record
  @invalid_attrs2 %{
    "driver" => "Yuki",
    "passenger" => "Masahisa",
    "car" => "Toyota Avalon",
    "created_at" => 1_522_883_972,
    "checkpoint" => 1_522_883_973,
    "extra" => nil
  }

  # Missing required attribute
  @partial_attrs1 %{
    "passenger" => "Masahisa",
    "car" => "Toyota Prius",
    "created_at" => 1_522_883_972,
    "extra" => nil
  }

  # Missing optional attribute
  @partial_attrs2 %{
    "driver" => "Kengo",
    "passenger" => "Masahisa",
    "car" => "Toyota Prius",
    "created_at" => 1_522_883_972
  }

  test "changeset with valid attributes 1" do
    changeset = Data.changeset(%Data{}, @valid_attrs1)
    assert changeset.valid?
  end

  test "changeset with valid attributes 2" do
    changeset = Data.changeset(%Data{}, @valid_attrs2)
    assert changeset.valid?
  end

  test "changeset with invalid attributes 1" do
    changeset = Data.changeset(%Data{}, @invalid_attrs1)

    assert [
             driver: {"can't be blank", [validation: :required]},
             created_at: {"is invalid", [type: :integer, validation: :cast]}
           ] = changeset.errors

    refute changeset.valid?
  end

  test "changeset with invalid attributes 2" do
    changeset = Data.changeset(%Data{}, @invalid_attrs2)

    assert [created_at: {"Stale value, 1522883972 not greater than 1522883973", []}] =
             changeset.errors

    refute changeset.valid?
  end

  test "changeset with partial attributes 1" do
    changeset = Data.changeset(%Data{}, @partial_attrs1)

    assert [
             driver: {"can't be blank", [validation: :required]}
           ] = changeset.errors

    refute changeset.valid?
  end

  test "changeset with partial attributes 2" do
    changeset = Data.changeset(%Data{}, @partial_attrs2)
    assert [] = changeset.errors
    assert true == changeset.valid?
  end
end
