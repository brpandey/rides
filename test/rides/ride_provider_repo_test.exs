defmodule Rides.RideProviderRepoTest do
  use ExUnit.Case

  alias Rides.Mapper.{Ride, Person, Provider, RideProvider}
  alias Rides.Repo

  @time 1_523_131_570
  @naive_date_time ~N[2018-04-07 20:06:10]
  @extra <<0>>

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  @valid_person_attr1 %{name: "Kengo"}
  @valid_person_attr2 %{name: "Akito"}
  @valid_person_attr3 %{name: "Shingo"}

  @valid_provider_attr1 %{name: "Ridebeam"}
  @valid_provider_attr2 %{name: "GinzaRides"}
  @valid_provider_attr3 %{name: "JRideShares"}

  @dummy_car "Toyota Avalon"

  test "successful ride provider creation" do
    # create two persons
    {:ok, %Person{} = pe1} = Person.create(@valid_person_attr1)
    {:ok, %Person{} = pe2} = Person.create(@valid_person_attr2)

    # create ride
    {:ok, %Ride{} = r} = Ride.create(pe1, pe2)

    # create provider
    {:ok, %Provider{} = p} = Provider.create(@valid_provider_attr1)
    # {:ok, %Provider{} = p2} = Provider.create(@valid_provider_attr2)

    {:ok, %RideProvider{}} = RideProvider.create(r, p, @dummy_car, @time, nil)
  end

  test "check foreign key constraint for invalid ride" do
    r = %Ride{id: 0}

    # create provider
    {:ok, %Provider{} = p} = Provider.create(@valid_provider_attr1)

    {:error, %Ecto.Changeset{errors: e}} = RideProvider.create(r, p, @dummy_car, @time, nil)

    assert [ride: {"does not exist", []}] = e
  end

  test "check foreign key constraint for invalid provider" do
    p = %Provider{id: 0}

    # create two persons
    {:ok, %Person{} = pe1} = Person.create(@valid_person_attr1)
    {:ok, %Person{} = pe2} = Person.create(@valid_person_attr2)

    # create ride
    {:ok, %Ride{} = r} = Ride.create(pe1, pe2)

    {:error, %Ecto.Changeset{errors: e}} = RideProvider.create(r, p, @dummy_car, @time, nil)

    assert [provider: {"does not exist", []}] = e
  end

  test "check ride and provider combination is unique via constraint error" do
    # create two persons
    {:ok, %Person{} = pe1} = Person.create(@valid_person_attr1)
    {:ok, %Person{} = pe2} = Person.create(@valid_person_attr2)

    # create ride
    {:ok, %Ride{} = r} = Ride.create(pe1, pe2)

    # create provider
    {:ok, %Provider{} = p} = Provider.create(@valid_provider_attr1)
    # {:ok, %Provider{} = p2} = Provider.create(@valid_provider_attr2)

    # create ride provider
    {:ok, %RideProvider{}} = RideProvider.create(r, p, @dummy_car, @time, nil)

    # create duplicate
    {:error, %Ecto.Changeset{errors: e}} = RideProvider.create(r, p, @dummy_car, @time, nil)

    assert [ride_id_provider_id: {"has already been taken", []}] = e
  end

  test "check ride and provider many to many relationship is accessible" do
    # create persons
    {:ok, %Person{} = pe1} = Person.create(@valid_person_attr1)
    {:ok, %Person{} = pe2} = Person.create(@valid_person_attr2)
    {:ok, %Person{} = pe3} = Person.create(@valid_person_attr3)

    # create rides
    {:ok, %Ride{id: rid1} = r1} = Ride.create(pe1, pe2)
    {:ok, %Ride{} = r2} = Ride.create(pe1, pe3)

    # create providers
    {:ok, %Provider{id: pid1} = p1} = Provider.create(@valid_provider_attr1)
    {:ok, %Provider{id: pid2} = p2} = Provider.create(@valid_provider_attr2)
    {:ok, %Provider{} = p3} = Provider.create(@valid_provider_attr3)

    # Unique ride provider 1
    {:ok, %RideProvider{} = rp1} = RideProvider.create(r1, p1, @dummy_car, @time, nil)

    assert @naive_date_time == rp1.created_at
    assert nil == rp1.extra

    # Unique ride provider 2
    {:ok, %RideProvider{id: rpid2} = rp2} = RideProvider.create(r1, p2, @dummy_car, @time, @extra)

    assert @naive_date_time == rp2.created_at
    assert @extra == rp2.extra

    # Check we can fetch properly as well
    assert %RideProvider{id: ^rpid2} = RideProvider.fetch(:ride_provider, r1, p2)
    assert nil == RideProvider.fetch(:ride_provider, r1, p3)

    # Ensure that we can access the many to many relationship
    # from Ride (via providers) and Provider (via rides)

    assert [%Provider{id: ^pid1}, %Provider{id: ^pid2}] = Ride.providers(r1)
    assert [%Ride{id: ^rid1}] = Provider.rides(p1)
    assert [%Ride{id: ^rid1}] = Provider.rides(p2)
    assert [] == Provider.rides(p3)
    assert [] == Ride.providers(r2)

    assert catch_error(Provider.rides(%Provider{id: 0})) ==
             %ArgumentError{
               message: "cannot retrieve association :rides for empty list"
             }
  end
end
