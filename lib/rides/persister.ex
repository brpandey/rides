defmodule Rides.Persister do
  @moduledoc """
  We fetch all the cached ride values, then persist to the db
  """

  require Logger
  alias Rides.{Cache, Repo, Manifest}
  alias Rides.Mapper.{Ride, Person, Provider, RideProvider}

  @keys Manifest.keys()

  # Sleep the first 15 seconds to allow web fetch routines to gather data
  @frequency 15 * 1000

  @doc """
  For each of the keys, fetch the data values from the cache
  Then write the values to the database

  NOTE: Could be turned into parallel insertions at some point
  NOTE: Would prefer to have had a second process to delete stale cache entries
  """
  def run(), do: run(@keys)

  def run(keys) when is_list(keys) do
    Process.sleep(@frequency)

    # NOTE IMPORTANT 
    # For the purpose of this example, we are ignoring 
    # the case where Cache.put(:data, k) might be called
    # after we do a Cache.get and before the Cache.delete

    # Ideally it would be good to have another parameter
    # as part of the key which references the exact chunks of data

    # Such that when we delete the data we are deleting only those
    # that we originally retrieved and not any new subsequent
    # data that has been inserted but the persister hasn't processed

    # NOTE 2
    # Also there should be better coordination between the persisting of ridees
    # and deletion of data, e.g. something more granular where for every record
    # that is written we delete that specific record from the cache

    # A bucket id could help here, specifically storing the data along side a bucket_id
    # AND then maintaining a separate association of bucket ids and status e.g. written to db, deleted

    Enum.map(keys, fn k ->
      rides = Cache.get(:data, k)
      persist({k, rides})
      Cache.delete(:data, k)
    end)
  end

  @doc "Routine takes the provider_key and rides list tuple, and persists each of the rides"
  def persist({provider_key, rides}) when is_binary(provider_key) and is_list(rides) do
    # Create the provider outside the transaction
    # Because we only need this done a small static number of times
    # and saves from having to do unnecessary DB queries just to keep
    # everything all in one transaction

    p =
      case Provider.fetch(:name, provider_key) do
        nil -> Provider.create!(provider_key)
        %Provider{} = p -> p
      end

    # Using each instead of map because a db write is a side effect
    Enum.each(rides, &persist_ride(p, &1))
  end

  @doc "Persists individual rides, setting up for the tail recursive do_build"
  def persist_ride(_pr, {d, p, _c, _ca, _e} = data)
      when is_binary(d) and is_binary(p) and d == p do
    Logger.warn("Ignoring ride with duplicate person names: #{inspect(data)}")
  end

  def persist_ride(pr, {d, p, c, ca, e})
      when is_binary(d) and is_binary(p) and is_integer(ca) and is_binary(c) and
             (is_nil(e) or is_binary(e)) do
    pd = Person.fetch(:name, d)
    pp = Person.fetch(:name, p)

    # We store everything in the map acc for now
    map_acc = %{driver: pd, passenger: pp, provider: pr}

    Logger.debug("persist case 0")

    do_build({pd, pp}, {d, p, c, ca, e}, map_acc)
  end

  # We build our transaction using tail recursion using an accumulator :)
  # Specifically we delay executing individual record creation until we
  # are in the final repo transaction block, so either we run all creation commands
  # at once or not at all keeping a clean db state  -- do_build!!

  defp do_build({nil, nil}, {d, p, _c, _ca, _e} = data, acc) do
    pd = fn -> Person.create!(d) end
    pp = fn -> Person.create!(p) end
    map = %{driver: pd, passenger: pp}

    Logger.debug("persist case 1")

    do_build({%Person{}, %Person{}}, data, Map.merge(acc, map))
  end

  defp do_build({%Person{}, nil}, {_d, p, _c, _ca, _e} = data, acc) do
    pp = fn -> Person.create!(p) end
    map = %{passenger: pp}

    Logger.debug("persist case 2")

    do_build({%Person{}, %Person{}}, data, Map.merge(acc, map))
  end

  defp do_build({nil, %Person{}}, {d, _p, _c, _ca, _e} = data, acc) do
    pd = fn -> Person.create!(d) end
    map = %{driver: pd}

    Logger.debug("persist case 3")

    do_build({%Person{}, %Person{}}, data, Map.merge(acc, map))
  end

  defp do_build({%Person{}, %Person{}}, {_d, _p, c, ca, e}, acc) do
    # Logger.debug("Transaction about start, acc is #{inspect(acc)}")

    try do
      Repo.transaction(fn ->
        # Fetch or create driver person
        pd =
          case Map.get(acc, :driver) do
            %Person{} = pd -> pd
            lambda when is_function(lambda) -> lambda.()
          end

        # Fetch or create passenger person
        pp =
          case Map.get(acc, :passenger) do
            %Person{} = pp -> pp
            lambda when is_function(lambda) -> lambda.()
          end

        # Fetch or create provider
        pr =
          case Map.get(acc, :provider) do
            %Provider{} = pr -> pr
            lambda when is_function(lambda) -> lambda.()
          end

        # These clauses don't have a ride or ride_provider previously
        # stored in the acc

        # Fetch or create ride
        r =
          case Ride.fetch(:driver_passenger, pd.name, pp.name) do
            nil -> %Ride{} = Ride.create!(pd, pp)
            %Ride{} = r -> r
          end

        # Fetch or create ride provider
        rp =
          case RideProvider.fetch(:ride_provider, r, pr) do
            nil -> %RideProvider{} = RideProvider.create!(r, pr, c, ca, e)
            %RideProvider{} = rp -> rp
          end

        Logger.debug(
          "Transaction end - (d #{pd.id}, pp #{pp.id}, r #{r.id}, pr #{pr.id}, r_p #{rp.id}) "
        )
      end)
    rescue
      e ->
        Logger.error("Repo transaction error #{inspect(e)}")
        []
    end
  end
end
