defmodule Rides.Cache do
  @moduledoc """
  Implements ETS Cache for stuffing newfound ride results from providers.
  Synchronizes put and delete operations, while get operations work without queueing

  ETS works well with concurrent writes and reads from many processes
  """

  require Logger

  @ets_table_name :rides_cache

  @doc """
  GenServer start link wrapper function
  """

  @spec start_link() :: {:ok, pid}
  def start_link() do
    options = [name: :rides_cache_server]
    GenServer.start_link(__MODULE__, :ok, options)
  end

  @doc """
  Routine to stop server normally
  """

  @spec stop() :: {}
  def stop() do
    GenServer.call(:rides_cache_server, :stop)
  end

  @doc "GenServer callback to initialize server process"

  # @callback init(term) :: {}
  def init(_) do
    # Loads ets table type set
    :ets.new(@ets_table_name, [:bag, :named_table, :public])
    {:ok, {}}
  end

  @doc """
  put -- 2 variants, put :data and :timestamp
  :data is for temporarily storing fetched worker data

  Put :data is synchronous and blocks (could easily be the other way)
  For higher volumnes would make sense to have a dedicated GenServer worker for "put"-ting
  So as not to block Cache GenServer while still being possibly synchronous
  """

  def put(:data, [], _) do
    Logger.warn("Empty :data to insert into ets")
  end

  def put(:data, [{_h, _a, _c, _ca, _e} | _tail] = list, provider_key)
      when is_binary(provider_key) do
    GenServer.call(:rides_cache_server, {:put_data, list, provider_key})
  end

  @doc "For storinga new provider related timestamp. Deletes the previous value"
  def put(:timestamp, {timestamp, provider_key})
      when is_integer(timestamp) and is_binary(provider_key) do
    t_key = {:timestamp, provider_key}

    # If timestamp is there already, delete it
    case :ets.lookup(@ets_table_name, t_key) do
      [{^t_key, data}] ->
        true = is_integer(data)
        :ets.delete(@ets_table_name, t_key)

      _ ->
        :ok
    end

    # put new timestamp
    case :ets.insert(@ets_table_name, {t_key, timestamp}) do
      true -> :ok
      false -> Logger.warn("Unable to successfully insert into ets")
    end
  end

  @doc "For deleting provider cache data.  Typically invoked after it has been written to db"
  def delete(:data, provider_key) when is_binary(provider_key) do
    GenServer.call(:rides_cache_server, {:delete_data, provider_key})
  end

  # Genserver callbacks around put and delete operations

  def handle_call({:put_data, list, pkey}, _from, state) do
    do_put(:data, list, pkey)
    {:reply, :ok, state}
  end

  def handle_call({:delete_data, pkey}, _from, state) do
    do_delete(:data, pkey)
    {:reply, :ok, state}
  end

  # callback to stop server

  # @callback handle_call(:atom, {}, {}) :: {}
  def handle_call(:stop, _from, {}) do
    {:stop, :normal, :ok, {}}
  end

  # GenServer callback to cleanup server state

  # @callback terminate(reason :: term, {}) :: term | no_return
  def terminate(_reason, _state) do
    :ok
  end

  @doc """
  get -- 2 variants, get :data and :timestamp
  :data is for fetching worker rides data
  :timestamp is for fetching worker timestamp info

  Neither is synchronous and is bound only by ETS concurrency
  """

  def get(:timestamp, provider_key) do
    t_key = {:timestamp, provider_key}

    case :ets.lookup(@ets_table_name, t_key) do
      [] ->
        nil

      [{^t_key, data}] ->
        true = is_integer(data)
        data
    end
  end

  def get(:data, provider_key) when is_binary(provider_key) do
    # create words key given length

    d_key = {:data, provider_key}

    case :ets.lookup(@ets_table_name, d_key) do
      [] ->
        []

      # Handles two cases in one
      # Case 1) Single value for key
      # Case 2) Multiple values for key (perhaps the persister process wasn't able to write them)
      #         and hence they weren't deleted
      [{^d_key, data} | _tail] = list when is_list(data) ->
        Enum.reduce(list, [], fn {^d_key, chunk}, acc ->
          List.flatten(chunk, acc)
        end)

      stuff ->
        Logger.error("Unsupported ets lookup value type, #{inspect(stuff)}")
    end
  end

  # Private implementation helpers which are used by GenServer callbacks
  # so that we can synchronize on these operations put and deletion of data

  defp do_put(:data, [{d, p, c, ca, e} | _tail] = list, provider_key)
       when is_binary(d) and is_binary(p) and is_binary(c) and is_integer(ca) and
              (is_nil(e) or is_binary(e)) and is_binary(provider_key) do
    # the data key is a tuple of :data and the provider_key
    d_key = {:data, provider_key}

    case :ets.insert(@ets_table_name, {d_key, list}) do
      true -> Logger.debug("Wrote to cache key: #{inspect(d_key)}, value: #{inspect(list)}")
      false -> Logger.error("Error, unable to insert into ETS")
    end
  end

  defp do_delete(:data, provider_key) when is_binary(provider_key) do
    # Check if data is there already 
    d_key = {:data, provider_key}

    case :ets.lookup(@ets_table_name, d_key) do
      [{^d_key, data} | _tail] when is_list(data) ->
        :ets.delete(@ets_table_name, d_key)

      _ ->
        :ok
    end
  end
end
