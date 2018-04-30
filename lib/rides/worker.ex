defmodule Rides.Worker do
  @moduledoc """
  Used as a generic template to interact with data providers 
  Used by Task Supervisor to fetch ride share data as part of Dispatcher

  Interacts with Rides.Cache and Rides.Data
  """

  @behaviour Rides.Provider

  require Logger
  use Retry
  use HTTPoison.Base
  alias Rides.{Data, Cache, Worker}

  @serialized_lob_field "extra"
  @json_identifier "rides"
  @query_cache_directive {:cache, "timestamp"}
  @default_content_type [{"Accept", "application/json"}]

  # http status codes
  @code_resource_unavailable 503
  @code_client_error 400
  @code_success 200

  defstruct key: nil, url: nil, query_params: nil, field_mappings: nil, dedup: nil

  @doc "Creates new worker struct using list arg"
  def new([
        {:key, key},
        {:url, url},
        {:query_params, query_p},
        {:field_mappings, field_m},
        {:dedup, dd}
      ]) do
    new(key, url, query_p, field_m, dd)
  end

  @doc "Creates new worker struct"
  def new(key, url, query_p, %{} = field_m, dd)
      when is_binary(key) and is_binary(url) and (is_nil(query_p) or is_map(query_p)) and
             is_boolean(dd) do
    %Worker{key: key, url: url, query_params: query_p, field_mappings: field_m, dedup: dd}
  end

  @doc "Wrapper method handles worker task which is data fetch and data store"
  def run(%Worker{} = w, sleep_time) when is_integer(sleep_time) do
    # We use the sleep time to delay the worker execution slightly
    Process.sleep(sleep_time)

    data = run(w, &fetch(&1))
    store(w, data)
  end

  @doc """
  Handles core worker task which is data fetching and response data processing 
  with configurable network request routine
  """
  def run(%Worker{} = w, fn_request) when is_function(fn_request, 1) do
    # The timestamp signifies the last time we had a successful
    # request so that we don't have to load a provider's full
    # data set if the provider supports specifying a timestamp parameter

    # We set the timestamp BEFORE we get the successful response
    timestamp = :os.system_time(:seconds)

    # Process query state so that it reflects the current query params
    # Process network request! 

    case fn_request.(query_resolver(w, :before_query)) do
      nil ->
        []

      {h, body} when is_list(h) and is_binary(body) ->
        # Since we received a successful response
        # Update the cache with the last successful timestamp fetch
        # Hence, upon the subsequent fetch for this provider
        # We can start at this point rather than from the beginning

        query_resolver(w, timestamp, :after_query)
        headers = headers_resolver(h)

        # Process response data and then store
        process_response(w, headers, body)
    end
  end

  @doc "Provides store method, in this instance we are storing to cache"
  def store(%Worker{}, []), do: :ok

  def store(%Worker{key: pkey}, data) when is_list(data) do
    Cache.put(:data, data, pkey)
  end

  @doc "Provides retrying rides fetch logic, retrying only when busy"
  def fetch(%Worker{url: url, query_params: query_p}) do
    try do
      result =
        retry with: exp_backoff() |> randomize() |> expiry(4_000) do
          Logger.debug("About to request #{inspect(url)}, query params are #{inspect(query_p)}")

          # Request application/json as content-type but that is not a guarentee, merely a request
          # retry gets triggered only if block returns :error
          case get!(url, @default_content_type, params: query_p) do
            %HTTPoison.Response{body: body, status_code: @code_resource_unavailable} ->
              Logger.debug("Retrying, received 503, body: #{inspect(body)}")
              {:error, body}

            r ->
              {:ok, r}
          end
        end

      case result do
        {:ok, %HTTPoison.Response{headers: h, body: body, status_code: @code_success}} ->
          Logger.debug("Received result: #{inspect(result)}")

          # Stuff headers e.g. content-type so we can pattern match during processing
          {h, body}

        {:ok, %HTTPoison.Response{body: body, status_code: @code_client_error}} ->
          Logger.error("Received 400 result: #{inspect(body)}")
          nil

        {:error, body} ->
          Logger.debug("Received 503 result: #{inspect(body)}")
          nil

        result ->
          Logger.error("Received unexpected result: #{inspect(result)}")
          nil
      end
    rescue
      e ->
        Logger.error("Fetch error #{inspect(e)}")
        nil
    end
  end

  @doc """
  Function normalizes the response fields so that it corresponds to the rides schema fields
  As needed the relevant data transformations are done

  The k and v in the Enum reduce correspond to the response record key and value

  Note: Supports serialized LOB DB pattern

  This is so we don't have to define extra db columns given variable extra provider fields, 
  The extra fields are put into a map, which is then serialized using MessagePack
  Then stored in a single column "extra"
  """

  def normalize(%Worker{field_mappings: %{} = fm}, %{} = record) do
    normalized =
      Enum.reduce(record, %{}, fn {k, v}, acc ->
        # We traverse through the response record key and value
        # and check to see if there is a matching rule (key) in the field_mappings
        # if so, we apply the rule based on the type
        case Map.get(fm, k) do
          # Handles case where the response key rides the name of the schema field
          ^k ->
            Map.put(acc, k, v)

          # Handles case when we need to do a quick transform given the source field
          # Hence we apply the lambda over the source field and stuff
          # the result into the renamed field
          {rename, lambda} when is_binary(rename) ->
            Map.put(acc, rename, lambda.(v))

          # Handles case where we want to rename the response key to rename
          # Stuff the value into the rename key
          rename when is_binary(rename) ->
            Map.put(acc, rename, v)

          # Handles case for when we have multiple keys map from the same source
          # E.g.  "passengers" => 
          # [{"driver", &Rides.Provider.Helper.split_first/1}, {"passenger", &Rides.Provider.Helper.split_last/1}]
          # value is "Tatsu - Akiko"
          # Store the lambda return values into the rename keys

          list when is_list(list) ->
            Enum.reduce(list, acc, fn {rename, lambda}, acc ->
              Map.put(acc, rename, lambda.(v))
            end)

          # Handles case of an extra match parameter e.g. score or mascot :)
          # Stuff the key e.g. (color) and its value (blue) into the extra acc map
          :extra ->
            term = %{"#{k}" => v}
            Map.update(acc, @serialized_lob_field, term, &Map.merge(&1, term))
        end
      end)

    # If the normalized record contains the @serialized_lob_field key, 
    # Binarize & compress it!

    case Map.get(normalized, @serialized_lob_field) do
      nil ->
        normalized

      %{} = map ->
        blob = Msgpax.pack!(map, iodata: false)
        Map.put(normalized, @serialized_lob_field, blob)
    end
  end

  # :before_query variant
  # Takes query params configuration and "resolves" it using the latest cached value
  defp query_resolver(%Worker{query_params: nil} = w, :before_query), do: %{w | query_params: %{}}

  defp query_resolver(%Worker{query_params: %{} = query_p, key: pkey} = w, :before_query) do
    # Example query params
    # %{"last_checked_at" => {:cache, "timestamp"}} to 
    # %{"last_checked_at" => 1523329057}

    entry =
      Enum.reduce(query_p, %{}, fn {k, v}, acc ->
        case v do
          @query_cache_directive ->
            case Cache.get(:timestamp, pkey) do
              nil -> acc
              cached when is_integer(cached) -> Map.put(acc, k, cached)
              _ -> Logger.error("Unsupported type for timestamp value")
            end

          # For everything else e.g. a value with a literal
          # %{"query_param_a" => 123456}
          # keep it in the map

          _ ->
            Map.put(acc, k, v)
        end
      end)

    # Store the process query resolver params back in the Worker struct query_params field
    # When the worker execution finishes it is not reused, so the re-stuffing in params is fine

    # When the dispatcher is fired off again, it uses the original query params struct

    # Hence  :query_params => %{"last_checked_at" => {:data_struct_fields, "last_timestamp"}},
    # is transformed into %{last_checked_at: t})

    %{w | query_params: entry}
  end

  # :after_query variant
  # Given a worker that uses query params and specifically the query cache directive
  # We ensure that we update the value for subsequent queries
  defp query_resolver(%Worker{key: pkey, query_params: qp}, time, :after_query)
       when is_integer(time) and is_map(qp) do
    # If we are setup with a query config that uses caching update the cache value
    case Map.values(qp) |> Enum.any?(&(&1 == @query_cache_directive)) do
      true -> Cache.put(:timestamp, {time, pkey})
      false -> :ok
    end
  end

  defp query_resolver(%Worker{}, _time, :after_query), do: :ok

  # Converts the headers list found in a response to a useable map structure that 
  # allows pattern matching key names in function heads
  defp headers_resolver(headers) when is_list(headers) do
    # Iterate through response headers lowercase-ing fields and putting into special atom keys

    Enum.reduce(headers, %{}, fn {k, v}, acc ->
      k = String.downcase(k)
      v = String.downcase(v)
      Map.put(acc, :"#{k}", v)
    end)
  end

  # Process response
  # Specifically pattern rides json response type

  defp process_response(
         %Worker{} = w,
         %{:"content-type" => "application/json; charset=utf-8"},
         body
       ) do
    process_response(w, %{:"content-type" => "application/json"}, body)
  end

  defp process_response(%Worker{} = w, %{:"content-type" => "application/json"}, body) do
    try do
      # decode json
      response = Poison.decode!(body)

      # Wrap the Enum reduce with logic to get the last timestamp
      # from the previous batch of records
      # and store the last timestamp
      # from the current records batch

      # assumes dedup is enabled, if not fine

      last = dedup_helper(w, :before_validates)

      # process rides list
      # build the list of records that pass validation 
      # while keeping track of the last/largest/newest created at value in the records set
      # assuming that records are dispensed by time

      {list, checkpoint} =
        Enum.reduce(response[@json_identifier], {[], 0}, fn record, {list_acc, last_acc} ->
          # Validate and normalize fields quickly
          changeset = Data.changeset(%Data{checkpoint: last}, record, &normalize(w, &1))

          case changeset.valid? do
            true ->
              # Since successful validated, apply changes to data struct
              data = Ecto.Changeset.apply_changes(changeset)

              # Keep track of last created_at value
              last_acc = if data.created_at > last_acc, do: data.created_at, else: last_acc

              # Ensure we get the right Data form, then prepend to acc
              dump = data |> Data.dump()
              list_acc = [dump] ++ list_acc

              {list_acc, last_acc}

            false ->
              # Unsuccessful validation (e.g. stale data), ignore the current record
              {list_acc, last_acc}
          end
        end)

      # Matching dedup helper routine which catalogues the checkpoint state for subsequent access
      dedup_helper(w, checkpoint, :after_validates)

      # Reverse the list so that it reflects how the data was structured
      list |> Enum.reverse()
    rescue
      e ->
        Logger.error("Processing response error #{inspect(e)}")
        []
    end
  end

  # Catch all process_response version, implementation reminder for when there are new content-types
  defp process_response(%Worker{}, %{} = headers, _body) do
    Logger.error("Unsupported content type #{inspect(headers)}")
    []
  end

  # Dedup private helpers to fetch and store checkpoint timestamps for use in Data changeset validation
  defp dedup_helper(%Worker{dedup: false, key: _}, :before_validates), do: 0

  defp dedup_helper(%Worker{dedup: true, key: pkey}, :before_validates) when is_binary(pkey) do
    case Cache.get(:timestamp, dedup_key(pkey)) do
      nil -> 0
      val when is_integer(val) -> val
    end
  end

  defp dedup_helper(%Worker{}, 0, :after_validates), do: :ok
  defp dedup_helper(%Worker{dedup: false, key: _pkey}, _, :after_validates), do: :ok

  defp dedup_helper(%Worker{dedup: true, key: pkey}, time, :after_validates)
       when is_binary(pkey) and is_integer(time) do
    Cache.put(:timestamp, {time, dedup_key(pkey)})
  end

  # Convenience function to create dedup key, allows us to potentially dedup
  # and also use query cache params without any key conflicts
  defp dedup_key(key) when is_binary(key), do: "#{key}-dedup"
end
