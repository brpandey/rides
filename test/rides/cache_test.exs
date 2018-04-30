defmodule Rides.CacheTest do
  use ExUnit.Case

  require Logger
  alias Rides.Cache

  @pkey "white rabbit"

  @timestamp1 1_523_122_728
  @timestamp2 1_523_132_728

  @data0 []

  @data1 [
    {"Kengo", "Miho", "Toyota Prius", 1_522_717_227, nil},
    {"Masahisa", "Shingo", "Toyota Camry", 1_522_717_232, nil},
    {"Kenji", "Nori", "Toyota Tundra", 1_522_717_237, nil},
    {"Fumiko", "Reiko", "Toyota Highlander", 1_522_717_242, nil}
  ]

  @data2 [
    {"Seiji", "Shinju", "Toyota Avalon Hybrid", 1_522_717_177,
     <<130, 165, 99, 111, 108, 111, 114, 49, 166, 109, 97, 115, 99, 111, 116, 165, 122, 101, 98,
       114, 97>>},
    {"Tamiko", "Ume", "Toyota Land Cruiser", 1_522_717_182,
     <<130, 165, 99, 111, 108, 111, 114, 50, 166, 109, 97, 115, 99, 111, 116, 165, 109, 111, 117,
       115, 101>>},
    {"Yoshiko", "Yuki", "Toyota Camry Hybrid", 1_522_717_187,
     <<130, 165, 99, 111, 108, 111, 114, 51, 166, 109, 97, 115, 99, 111, 116, 163, 101, 109, 117>>},
    {"Yuki", "Katsuro", "Toyota LC500", 1_522_717_192,
     <<130, 165, 99, 111, 108, 111, 114, 52, 166, 109, 97, 115, 99, 111, 116, 167, 103, 105, 114,
       97, 102, 102, 101>>}
  ]

  # Combination of data1 and data2

  @data3 [
    {"Seiji", "Shinju", "Toyota Avalon Hybrid", 1_522_717_177,
     <<130, 165, 99, 111, 108, 111, 114, 49, 166, 109, 97, 115, 99, 111, 116, 165, 122, 101, 98,
       114, 97>>},
    {"Tamiko", "Ume", "Toyota Land Cruiser", 1_522_717_182,
     <<130, 165, 99, 111, 108, 111, 114, 50, 166, 109, 97, 115, 99, 111, 116, 165, 109, 111, 117,
       115, 101>>},
    {"Yoshiko", "Yuki", "Toyota Camry Hybrid", 1_522_717_187,
     <<130, 165, 99, 111, 108, 111, 114, 51, 166, 109, 97, 115, 99, 111, 116, 163, 101, 109, 117>>},
    {"Yuki", "Katsuro", "Toyota LC500", 1_522_717_192,
     <<130, 165, 99, 111, 108, 111, 114, 52, 166, 109, 97, 115, 99, 111, 116, 167, 103, 105, 114,
       97, 102, 102, 101>>},
    {"Kengo", "Miho", "Toyota Prius", 1_522_717_227, nil},
    {"Masahisa", "Shingo", "Toyota Camry", 1_522_717_232, nil},
    {"Kenji", "Nori", "Toyota Tundra", 1_522_717_237, nil},
    {"Fumiko", "Reiko", "Toyota Highlander", 1_522_717_242, nil}
  ]

  setup _context do
    cache_pid =
      case Cache.start_link() do
        {:ok, pid} ->
          pid

        {:error, {:already_started, pid}} ->
          pid
      end

    on_exit(fn ->
      # Ensure the pass servers are shutdown with non-normal reason
      Process.exit(cache_pid, :shutdown)

      # Wait until the servers are dead
      cache_ref = Process.monitor(cache_pid)

      assert_receive {:DOWN, ^cache_ref, _, _, _}
    end)

    :ok
  end

  # def get(:data, provider_key) when is_binary(provider_key) do
  # def put(:data, [], _) do  
  # def put(:data, [{h, a, c, ca, e} | _tail] = list, provider_key)

  test "data get, put, get, put, get that acts like a bag type" do
    assert [] == Cache.get(:data, @pkey)

    # put
    Cache.put(:data, @data1, @pkey)

    # success read
    assert @data1 == Cache.get(:data, @pkey)

    Cache.put(:data, @data2, @pkey)

    # success read is a combination of data1 and data2
    # since type is a bag and we don't delete we get both
    assert @data3 == Cache.get(:data, @pkey)

    # this is a non-insert
    Cache.put(:data, @data0, @pkey)

    # data should be the same from the previous success read
    assert @data3 == Cache.get(:data, @pkey)

    # finally remove data
    Cache.delete(:data, @pkey)

    # finally nothing
    assert [] == Cache.get(:data, @pkey)

    Cache.stop()
  end

  # def get(:timestamp, provider_key) do
  # def put(:timestamp, {timestamp, provider_key})

  test "timestamp get, put, get, put, get that acts like a set type" do
    # nil read
    assert nil == Cache.get(:timestamp, @pkey)

    # put

    Cache.put(:timestamp, {@timestamp1, @pkey})

    # success read
    assert @timestamp1 == Cache.get(:timestamp, @pkey)

    Cache.put(:timestamp, {@timestamp2, @pkey})

    # success read
    assert @timestamp2 = Cache.get(:timestamp, @pkey)

    Cache.stop()
  end
end
