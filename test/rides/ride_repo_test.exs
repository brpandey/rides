defmodule Rides.RideRepoTest do
  use ExUnit.Case

  alias Rides.Mapper.{Ride, Person}
  alias Rides.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  @invalid_ride_attr1 %{driver_id: 1, passenger_id: 0}

  @valid_person_attr1 %{name: "Kengo"}
  @valid_person_attr2 %{name: "Shingo"}
  @valid_person_attr3 %{name: "Masahisa"}

  test "check foreign key constraint for valid persons id" do
    # insert two persons into db

    {:ok, %Person{id: id1}} = Person.create(@valid_person_attr1)
    {:ok, %Person{id: id2}} = Person.create(@valid_person_attr2)

    params = %{driver_id: id1, passenger_id: id2}

    {:ok, %Ride{}} = %Ride{} |> Ride.changeset(params) |> Repo.insert()
  end

  test "check foreign key constraint for invalid passenger person id" do
    {:ok, %Person{id: driver_id}} = Person.create(@valid_person_attr1)

    invalid_ride_attrs = %{driver_id: driver_id, passenger_id: 0}

    {:error, %Ecto.Changeset{errors: e}} =
      %Ride{} |> Ride.changeset(invalid_ride_attrs) |> Repo.insert()

    assert [passenger: {"does not exist", []}] = e
  end

  test "check foreign key constraint for invalid driver person id" do
    {:error, %Ecto.Changeset{errors: e}} =
      %Ride{}
      |> Ride.changeset(@invalid_ride_attr1)
      |> Repo.insert()

    assert [driver: {"does not exist", []}] = e
  end

  test "check changeset validation where both persons must be unique" do
    {:ok, %Person{} = p1} = Person.create(@valid_person_attr1)

    {:error, %Ecto.Changeset{errors: e}} = Ride.create(p1, p1)

    assert [
             passenger_id:
               {"can't share value with driver_id",
                [info: "A person can't duplicate itself in a ride"]}
           ] = e
  end

  test "check driver and passenger person combination is unique - unsuccessful" do
    # insert two persons into db

    {:ok, %Person{} = p1} = Person.create(@valid_person_attr1)
    {:ok, %Person{} = p2} = Person.create(@valid_person_attr2)

    # Unique ride 1
    {:ok, %Ride{}} = Ride.create(p1, p2)

    # Duplicate ride 1
    {:error, %Ecto.Changeset{errors: e}} = Ride.create(p1, p2)
    assert [driver_id_passenger_id: {"has already been taken", []}] = e

    # New ride 2
    {:ok, %Ride{}} = Ride.create(p2, p1)
  end

  test "check driver and passenger person combination is unique - successful" do
    # insert two persons into db

    {:ok, %Person{} = p1} = Person.create(@valid_person_attr1)
    {:ok, %Person{} = p2} = Person.create(@valid_person_attr2)
    {:ok, %Person{} = p3} = Person.create(@valid_person_attr3)

    # Unique ride 1
    {:ok, %Ride{}} = Ride.create(p1, p2)

    # Unique ride 2
    {:ok, %Ride{}} = Ride.create(p1, p3)
  end

  test "check query methods given person names" do
    # Unique persons
    {:ok, %Person{} = p1} = Person.create(@valid_person_attr1)
    {:ok, %Person{} = p2} = Person.create(@valid_person_attr2)
    {:ok, %Person{} = p3} = Person.create(@valid_person_attr3)

    # Unique ride 1
    {:ok, %Ride{id: rid1} = r1} = Ride.create(p1, p2)

    # Unique ride 2
    {:ok, %Ride{id: rid2} = r2} = Ride.create(p1, p3)

    assert [%Ride{id: ^rid1}, %Ride{id: ^rid2}] = Ride.fetch(:driver, p1.name)

    passenger = %Person{} = Ride.passenger(r1)
    assert passenger.name == p2.name

    driver = %Person{} = Ride.driver(r2)
    assert driver.name == p1.name

    assert %Ride{id: ^rid1} = Ride.fetch(:driver_passenger, p1.name, p2.name)

    # These two don't have a ride
    assert nil == Ride.fetch(:driver_passenger, p2.name, p3.name)

    assert [%Ride{id: ^rid2}] = Ride.fetch(:passenger, p3.name)

    assert [] == Ride.fetch(:driver, p3.name)
  end
end
