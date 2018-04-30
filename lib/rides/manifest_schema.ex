defmodule Rides.Manifest.Schema do
  @moduledoc """
  Provides Schema definition and validating operations around Manifest

  Ensures a given Manifest is well formed.
  Uses a pipe-line flow for validation.
  Flips field mappings from initial format for easier response processing

  Strives to be extendable
  """

  require Logger

  # Field names
  @active :active
  @format :format
  @key :key
  @url :url
  @mappings :field_mappings

  @manifest :manifest
  @custom :custom

  # Field mapping names
  @field_driver "driver"
  @field_passenger "passenger"
  @field_created_at "created_at"
  @field_car "car"
  @field_extra "extra"
  @field_extra_atom :extra

  # Optional fields
  @query_params :query_params
  @cache :cache
  @dedup :dedup

  # Schema information
  @manifest_cache_keys MapSet.new(["timestamp"])
  @manifest_required_keys MapSet.new([@active, @format, @key, @url, @mappings])
  @manifest_required_mappings MapSet.new([
                                @field_driver,
                                @field_passenger,
                                @field_created_at,
                                @field_car,
                                @field_extra
                              ])

  @custom_required_keys MapSet.new([@active, @format, @key])

  # reduce_while directive attributes
  @cont {:cont, :ok}
  @skip {:cont, :skip}

  _ = """
  Example manifest map

  %{
    # Specify the provider manifest entry for GinzaRides
    :ginza => %{
      :active => true,
      :format => :manifest,
      # Key to store provider id alongside fetched ride data tuple
      :key => "GinzaRides",
      # Specify if any query params are used (as it is optional)
      # Specify how to obtain query param value either static value
      # or mapping to provider struct field name
      :query_params => %{"last_checked_at" => {@cache, "timestamp"}},
      # Specify response field mappings to provider fields
      :field_mappings => %{
        "driver" => "driver",
        "passenger" => "passenger",
        "created_at" => "created_at",
        "car" => "car",
        "extra" => nil
      },
      # Specify endpoint url
      :url => "http://0.0.0.0:4000/feed/v1/ginzarides"
    },
    # Specify the provider manifest entry for Kamakurashares
    :kamakura => %{
      :active => true,
      :format => :manifest,
      # Key to store provider id alongside fetched ride data tuple
      :key => "Kamakurashares",
      # Specify response field mappings to provider fields
      :field_mappings => %{
        "driver" => {"passengers", &Helper.split_first/1},
        "passenger" => {"passengers", &Helper.split_last/1},
        "created_at" => "created_at",
        "car" => "car",
        "extra" => nil
      },
      # Specify endpoint url
      :url => "http://0.0.0.0:4000/feed/v1/kamakurashares",
      :dedup => true
    },

    # Specify the provider manifest entry for provider x
    :provider_k => %{
      :active => true,
      :format => {:custom, Rides.Provider.X},
      # Key to store provider id alongside fetched ride data tuple
      :key => "Provider X Key"
    }
  }
  """

  @doc """
  Given a manifest with provider entries ensures high-level validation checkes are met
  """
  def validate(%{} = providers) do
    # Ensure the manifest entries are well formed by validating
    # each provider entry

    flag =
      Enum.reduce_while(providers, :ok, fn {k, %{} = p_entry}, _acc ->
        # Ensure required keys are present

        pipe_check_start(:ok)
        |> pipe_check_required_keys(p_entry, k)
        |> pipe_check_required_mappings(p_entry, k)
        |> pipe_check_opt_query_params(p_entry, k)
        |> pipe_check_finish
      end)

    case flag do
      :ok -> :ok
      msg -> raise ArgumentError, message: msg
    end
  end

  @doc "Helper routine to instantiate Worker"
  def entry(%{active: false}), do: nil

  def entry(%{active: true, format: :manifest} = entry) do
    key = Map.get(entry, @key)
    query_p = Map.get(entry, @query_params)
    field_m = Map.get(entry, @mappings) |> mappings_resolver()
    url = Map.get(entry, @url)

    dd =
      case Map.get(entry, @dedup) do
        true -> true
        _ -> false
      end

    {:ok,
     [
       {:key, key},
       {:url, url},
       {:query_params, query_p},
       {:field_mappings, field_m},
       {:dedup, dd}
     ]}
  end

  def entry(%{active: true, format: {:custom, module}}) do
    {:ok, {:module, module}}
  end

  # Convenient routine for field_mappings

  # Swaps the key and values so when we need to normalize it, 
  # it is easier to process the fields since typically we proceed
  # from the provider's fields and map it back to the schema fields

  defp mappings_resolver(%{} = m) do
    Enum.reduce(m, %{}, fn {k, v}, acc ->
      # When we read the response fields we will see "teams" and then 
      # that allows us to easily check if there is a rule (or key) for "teams"

      #        :field_mappings => %{
      #          "driver" => {"passengers", fn v -> String.split(v, " - ") |> List.first() end},
      #          "passenger" => {"passengers", fn v -> String.split(v, " - ") |> List.last() end},
      #        }

      # transformed to ->

      #        :field_mappings => %{
      #          "passengers" => [
      #                       {"driver", fn v -> String.split(v, " - ") |> List.first() end},
      #                       {"passenger", fn v -> String.split(v, " - ") |> List.last() end}
      #                     ]
      #        }

      # Note: Todo, should check for duplicate values

      case v do
        # Flip the k -> {v1, v2_func) to v1 -> {k, v2 func} -- see above
        {source, func} when is_binary(source) and k in [@field_driver, @field_passenger] ->
          # Originally was Map.put(acc, source, {k, func})
          # but to handle duplicates we prepend to list
          # v is the current value already present given the source key

          Map.update(acc, source, {k, func}, fn
            # delineate between the two cases of if we have
            # a tuple or list already as our value (as it affects how we do flatten)
            v when is_list(v) ->
              List.flatten([{k, func}], v)

            v when is_tuple(v) ->
              List.flatten([{k, func}], [v])
          end)

        # Just a flip of the value and key names
        v
        when is_binary(v) and
               k in [@field_driver, @field_passenger, @field_created_at, @field_car] ->
          Map.put(acc, v, k)

        # If we have a list of values and the field is extra
        # Put each of these extra fields as keys with value :extra
        # Further down the line, the processing logic will know to put them into an "extra" map
        values when is_list(values) and k in [@field_extra] ->
          Enum.reduce(values, acc, fn v, acc2 ->
            Map.put(acc2, v, @field_extra_atom)
          end)

        nil when k in [@field_extra] ->
          acc
      end
    end)
  end

  # We chain the checks such that each check is performed after the previous
  # We can bypass all next checks by returning {:cont, :skip} or error with {:halt, msg}

  # Initial start of pipeline
  defp pipe_check_start(:ok), do: @cont

  # First check -- check required keys -- branches off to two mini pipelines
  defp pipe_check_required_keys(@cont, %{} = entry, tag) do
    case Map.get(entry, @format) do
      nil -> {:halt, "Manifest entry for #{inspect(tag)} is missing required format key"}
      @manifest -> pipe_check_required_manifest_keys(entry, tag)
      {@custom, _lambda} -> pipe_check_required_custom_keys(entry, tag)
    end
  end

  # Second check - 2A -- check custom keys as we are going to be using a custom implementation module
  defp pipe_check_required_custom_keys(%{format: {:custom, module}} = entry, tag) do
    # If active found, bypass other checks in validation pipeline by skipping
    flag1 = @custom_required_keys |> Enum.all?(&Map.has_key?(entry, &1))

    # Ensure module supports the Rides.Provider behaviour
    flag2 = function_exported?(module, :new, 1)
    flag3 = function_exported?(module, :run, 2)
    flag4 = function_exported?(module, :store, 2)

    # Logger.info("module is #{inspect(module)} flags are #{flag1} #{flag2} #{flag3} #{flag4}")

    case Enum.all?([flag1, flag2, flag3, flag4], & &1) do
      true ->
        @skip

      false ->
        {:halt,
         "Custom manifest entry for #{inspect(tag)} is not well formed as it doesn't contain the required custom keys or doesn't implement the Rides.Provider behaviour properly"}
    end
  end

  # Second check - 2B -- check required manifest keys as we are using the manifest type
  defp pipe_check_required_manifest_keys(%{format: :manifest} = entry, tag) do
    case @manifest_required_keys |> Enum.all?(&Map.has_key?(entry, &1)) do
      true -> @cont
      false -> {:halt, "Manifest entry for #{inspect(tag)} is missing required keys"}
    end
  end

  # Third check - 3B -- check required field mappings
  defp pipe_check_required_mappings({:halt, _str} = next, _entry, _t), do: next
  defp pipe_check_required_mappings(@skip, _entry, _t), do: @skip

  defp pipe_check_required_mappings(@cont, %{} = entry, tag) do
    field_m = %{} = Map.get(entry, @mappings)

    case @manifest_required_mappings |> Enum.all?(&Map.has_key?(field_m, &1)) do
      true ->
        # The required fields are present,
        # Now ensure each of the field mapping values have the proper form
        proper_form =
          Enum.all?(field_m, fn {k, v} ->
            case v do
              nil when k in [@field_extra] ->
                true

              v
              when is_binary(v) and
                     k in [@field_driver, @field_passenger, @field_created_at, @field_car] ->
                true

              {source, func}
              when is_binary(source) and is_function(func, 1) and
                     k in [@field_driver, @field_passenger] ->
                true

              v when is_list(v) and is_binary(hd(v)) and k in [@field_extra] ->
                true

              stuff ->
                Logger.warn(
                  "Unsupported notation for required field mapping value #{inspect(stuff)}, given key #{
                    inspect(k)
                  }"
                )

                false
            end
          end)

        case proper_form do
          true -> @cont
          false -> {:halt, "Manifest entry for #{inspect(tag)} has improper field mappings"}
        end

      false ->
        {:halt, "Manifest entry for #{inspect(tag)} has incomplete field mappings"}
    end
  end

  # Fourth check - 4B - optional check of query params (as query params aren't required)
  defp pipe_check_opt_query_params(@cont, %{query_params: %{} = qp}, tag) do
    if Enum.all?(qp, &query_params_validate(&1)) do
      @cont
    else
      {:halt, "Manifest entry for #{inspect(tag)} has improper query params"}
    end
  end

  defp pipe_check_opt_query_params(@cont, %{}, _t), do: @cont
  defp pipe_check_opt_query_params(@skip, _entry, _t), do: @skip
  defp pipe_check_opt_query_params({:halt, _str} = next, _entry, _t), do: next

  # Finally last boilerplate stage of pipeline
  defp pipe_check_finish({:halt, _str} = next), do: next
  defp pipe_check_finish(@skip), do: @cont
  defp pipe_check_finish(@cont), do: @cont

  # Quick validations of query params
  # If the cache feature is referenced,
  # ensure the cache_key is present in the schema as a valid key

  defp query_params_validate({k, {@cache, cache_key}}) when is_binary(k),
    do: MapSet.member?(@manifest_cache_keys, cache_key)

  defp query_params_validate({k, _v}) when is_binary(k), do: true
  defp query_params_validate({_k, _v}), do: false
end
