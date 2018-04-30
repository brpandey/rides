defmodule Rides.PersisterTest do
  use ExUnit.Case, async: true

  alias Rides.{Persister, Repo}
  alias Rides.Mapper.{Ride, RideProvider}

  @pkey1 "Kamakurashares"
  @pkey2 "GinzaRides"

  @data0 {@pkey1, []}

  @data1a {@pkey1, [{"Kengo", "Akita", "Toyota Tundra", 1_523_122_728, nil}]}
  @data1b {@pkey1, [{"Kengo", "Kengo", "Toyota Tundra", 1_523_122_728, nil}]}

  # TEAM ALREADY CREATED
  @data2 {@pkey1,
          [
            {"Kengo", "Akita", "Toyota Tundra", 1_523_122_728, nil},
            {"Daichi", "Kengo", "Toyota Camry", 1_523_122_733, nil},
            {"Katsu", "Hikaru", "Toyota Prius", 1_523_122_738, nil},
            {"Katsu", "Emiko", "Toyota Avalon", 1_523_122_743, nil},
            {"Emiko", "Chika", "Toyota Highlander", 1_523_122_753, nil}
          ]}

  # RIDE ALREADY CREATED
  # Case 1 (same provider)  Should not error in ride_provider table since we check if exists
  @data3 {@pkey1,
          [
            {"Kengo", "Akita", "Toyota Tundra", 1_523_122_728, nil},
            {"Kengo", "Akita", "Toyota Tundra", 1_523_122_728, nil}
          ]}

  # Case 2 (different providers) Use data4 and data5 together
  # Should not error since different providers

  @data4 {@pkey1,
          [
            {"Kengo", "Akita", "Toyota Tundra", 1_523_122_728, nil},
            {"Miho", "Hikaru", "Toyota Prius", 1_523_122_738, nil}
          ]}

  @data5 {@pkey2,
          [
            {"Kengo", "Akita", "Toyota Tundra", 1_523_122_728, nil},
            {"Miho", "Hikaru", "Toyota Prius", 1_523_122_738, nil}
          ]}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "empty rides list" do
    assert :ok == Persister.persist(@data0)
  end

  test "single provider, single ride" do
    assert [] == Ride.fetch(:driver, "Kengo")

    # {"Kengo", "Akita", "Toyota Tundra", 1_523_122_728, nil},

    assert :ok == Persister.persist(@data1a)

    [r1] = Ride.fetch(:driver, "Kengo")
    assert "Akita" == Ride.passenger(r1).name

    [p] = Ride.providers(r1)

    assert @pkey1 == p.name

    rp = %RideProvider{} = RideProvider.fetch(:ride_provider, r1, p)

    assert ~N[2018-04-07 17:38:48.000000] == rp.created_at

    assert 1_523_122_728 == rp.created_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()

    assert nil == rp.extra
  end

  test "single provider, single ride but same teams" do
    assert [] == Ride.fetch(:driver, "Kengo")

    assert :ok == Persister.persist(@data1b)
  end

  test "single provider, rides with teams being reused" do
    assert :ok == Persister.persist(@data2)

    # 1 {"Kengo", "Akita", "Toyota Tundra", 1_523_122_728, nil},
    # 2 {"Daichi", "Kengo", "..", 1_523_122_733, nil},
    # 3 {"Katsu", "Hikaru", "..", 1_523_122_738, nil},
    # 4 {"Katsu", "Emiko", "..", 1_523_122_743, nil},
    # 5 {"Emiko", "Chika", "..", 1_523_122_753, nil}

    [r2] = Ride.fetch(:passenger, "Kengo")
    assert "Daichi" == Ride.driver(r2).name

    [r3, r4] = Ride.fetch(:driver, "Katsu")
    assert "Hikaru" == Ride.passenger(r3).name
    assert "Emiko" == Ride.passenger(r4).name

    [r5] = Ride.fetch(:driver, "Emiko")
    assert "Chika" == Ride.passenger(r5).name

    [p] = Ride.providers(r5)
    assert "Kamakurashares" == p.name
  end

  test "duplicate ride same provider" do
    # 1 {"Kengo", "Akita", "Toyota Tundra", 1_523_122_728, nil},
    # 2 {"Kengo", "Akita", "Toyota Tundra", 1_523_122_728, nil}

    assert :ok == Persister.persist(@data3)

    [r1] = Ride.fetch(:driver, "Kengo")
    assert "Akita" == Ride.passenger(r1).name

    [p] = Ride.providers(r1)

    assert @pkey1 == p.name
  end

  test "same rides but different providers " do
    # 1 {"Kengo", "Akita", "Toyota Tundra", 1_523_122_728, nil},
    # 2 {"Kengo", "Akita", "Toyota Tundra", 1_523_122_728, nil}

    assert :ok == Persister.persist(@data4)
    assert :ok == Persister.persist(@data5)

    # We should have two providers for this ride

    [r1] = Ride.fetch(:driver, "Kengo")

    [p1, p2] = Ride.providers(r1)

    assert @pkey1 == p1.name
    assert @pkey2 == p2.name
  end
end
