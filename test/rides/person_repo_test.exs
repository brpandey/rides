defmodule Rides.PersonRepoTest do
  use ExUnit.Case

  alias Rides.{Mapper.Person, Mapper.Ride, Repo}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  @valid_person_attr1 %{name: "Kengo"}
  @valid_person_attr2 %{name: "Shingo"}
  @valid_person_attr3 %{name: "Akita"}

  @invalid_person_attr1 %{name: nil}
  @invalid_person_attr2 %{name: 3}

  test "check successful creation of valid persons" do
    {:ok, %Person{}} = Person.create(@valid_person_attr1)
    {:ok, %Person{}} = Person.create(@valid_person_attr2)
  end

  test "check unsuccessful creation of duplicate person" do
    {:ok, %Person{}} = Person.create(@valid_person_attr1)
    {:error, %Ecto.Changeset{errors: e}} = Person.create(@valid_person_attr1)

    assert [name: {"has already been taken", []}] = e
  end

  test "check unsuccessful creation of nil person" do
    {:error, %Ecto.Changeset{errors: e}} = @invalid_person_attr1 |> Person.create()

    assert [name: {"can't be blank", [validation: :required]}] = e
  end

  test "check unsuccessful creation of person with invalid type" do
    {:error, %Ecto.Changeset{errors: e}} = @invalid_person_attr2 |> Person.create()

    assert [name: {"is invalid", [type: :string, validation: :cast]}] = e
  end

  test "check person rides associations" do
    # 3 unique persons
    {:ok, %Person{id: id1} = p1} = Person.create(@valid_person_attr1)
    {:ok, %Person{id: id2} = p2} = Person.create(@valid_person_attr2)
    {:ok, %Person{id: id3} = p3} = Person.create(@valid_person_attr3)

    # Unique ride 1
    {:ok, %Ride{}} = Ride.create(p1, p2)

    # Unique ride 2
    {:ok, %Ride{}} = Ride.create(p1, p3)

    # Unique ride 3
    {:ok, %Ride{}} = Ride.create(p2, p3)

    # Unique ride 4
    {:ok, %Ride{}} = Ride.create(p2, p1)

    # Check the rides associations
    # p2, p3, p2
    assert [
             %Ride{driver_id: ^id1, passenger_id: ^id2},
             %Ride{driver_id: ^id1, passenger_id: ^id3},
             %Ride{driver_id: ^id2, passenger_id: ^id1}
           ] = Person.rides(p1)

    # p2, p3
    assert [
             %Ride{driver_id: ^id1, passenger_id: ^id2},
             %Ride{driver_id: ^id1, passenger_id: ^id3}
           ] = Person.rides_driver(p1)

    # p2
    assert [
             %Ride{driver_id: ^id2, passenger_id: ^id1}
           ] = Person.rides_passenger(p1)

    # p1, p2
    assert [
             %Ride{driver_id: ^id1, passenger_id: ^id3},
             %Ride{driver_id: ^id2, passenger_id: ^id3}
           ] = Person.rides_passenger(p3)

    # nil
    assert [] = Person.rides_driver(p3)
  end
end
