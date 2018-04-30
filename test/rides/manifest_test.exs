defmodule Rides.ManifestTest do
  use ExUnit.Case, async: true

  alias Rides.Manifest

  @valid_providers1 [
    %Rides.Worker{
      field_mappings: %{
        "passenger" => "passenger",
        "created_at" => "created_at",
        "car" => "car",
        "driver" => "driver"
      },
      key: "GinzaRides",
      query_params: %{"last_checked_at" => {:cache, "timestamp"}},
      url: "http://0.0.0.0:4000/feed/v1/ginzarides",
      dedup: false
    },
    %Rides.Worker{
      field_mappings: %{
        "created_at" => "created_at",
        "car" => "car",
        "occupants" => [
          {"passenger", &Rides.Manifest.Helper.split_last/1},
          {"driver", &Rides.Manifest.Helper.split_first/1}
        ]
      },
      key: "Kamakurashares",
      query_params: nil,
      url: "http://0.0.0.0:4000/feed/v1/kamakurashares",
      dedup: true
    },
    {Rides.ManifestTest.Fonzee, :ok}
  ]

  test "valid manifest entries of :manifest and :custom type" do
    providers = Manifest.load(manifest1())

    assert @valid_providers1 == providers

    keys = Manifest.keys(manifest1())

    assert ["GinzaRides", "Kamakurashares", "Fonzee Bear"] = keys
  end

  test "invalid manifest entries mix of :manifest and :custom" do
    # ginzarides missing key, and gonzo missing active
    assert catch_error(Manifest.load(manifest2())) == %ArgumentError{
             message: "Manifest entry for :ginza is missing required keys"
           }

    keys = Manifest.keys(manifest2())

    assert [nil, "Gonzo"] == keys
  end

  test "invalid manifest entry :manifest type" do
    # ginzarides missing passenger field_mapping
    assert catch_error(Manifest.load(manifest3())) == %ArgumentError{
             message: "Manifest entry for :ginza has incomplete field mappings"
           }

    keys = Manifest.keys(manifest3())

    assert ["GinzaRides"] == keys
  end

  test "invalid manifest entry :custom with unimplemented custom module" do
    # kermit module name doesn't exist (hence doesn't implement behaviour)
    assert catch_error(Manifest.load(manifest4())) == %ArgumentError{
             message:
               "Custom manifest entry for :kermit is not well formed as it doesn't contain the required custom keys or doesn't implement the Rides.Provider behaviour properly"
           }

    keys = Manifest.keys(manifest4())

    assert ["Green guy"] == keys
  end

  # valid manifest map
  def manifest1() do
    %{
      # Specify the provider manifest entry for Kamakurashares
      :kamakura => %{
        :active => true,
        :format => :manifest,
        # Key to store provider id alongside fetched ride data tuple
        :key => "Kamakurashares",
        # Specify json response field mappings to provider fields
        :field_mappings => %{
          "driver" => {"occupants", &Rides.Manifest.Helper.split_first/1},
          "passenger" => {"occupants", &Rides.Manifest.Helper.split_last/1},
          "car" => "car",
          "created_at" => "created_at",
          "extra" => nil
        },
        # Specify endpoint url
        :url => "http://0.0.0.0:4000/feed/v1/kamakurashares",
        # Specify dedup
        :dedup => true
      },

      # Specify the provider manifest entry for GinzaRides
      :ginza => %{
        :active => true,
        :format => :manifest,
        # Key to store provider id alongside fetched ride data tuple
        :key => "GinzaRides",
        # Specify if any query params are used (as it is optional)
        # Specify how to obtain query param value either static value
        # or mapping to provider struct field name
        :query_params => %{"last_checked_at" => {:cache, "timestamp"}},
        # Specify json response field mappings to provider fields
        :field_mappings => %{
          "driver" => "driver",
          "passenger" => "passenger",
          "car" => "car",
          "created_at" => "created_at",
          "extra" => nil
        },
        # Specify endpoint url
        :url => "http://0.0.0.0:4000/feed/v1/ginzarides"
      },
      :wakawaka => %{
        :active => true,
        :format => {:custom, Rides.ManifestTest.Fonzee},
        # Key to store provider id alongside fetched ride data tuple
        :key => "Fonzee Bear"
      }
    }
  end

  # ginza missing key, and gonzo missing active
  def manifest2() do
    %{
      # Specify the provider manifest entry for GinzaRides
      :ginza => %{
        :active => true,
        :format => :manifest,
        # Key to store provider id alongside fetched ride data tuple
        # Specify if any query params are used (as it is optional)
        # Specify how to obtain query param value either static value
        # or mapping to provider struct field name
        :query_params => %{"last_checked_at" => {:cache, "timestamp"}},
        # Specify json response field mappings to provider fields
        :field_mappings => %{
          "driver" => "driver",
          "passenger" => "passenger",
          "car" => "car",
          "created_at" => "created_at",
          "extra" => nil
        },
        # Specify endpoint url
        :url => "http://0.0.0.0:4000/feed/v1/ginzarides"
      },
      :gonzo => %{
        :format => {:custom, Rides.ManifestTest.Gonzo},
        # Key to store provider id alongside fetched ride data tuple
        :key => "Gonzo"
      }
    }
  end

  # ginza missing passenger field_mapping
  def manifest3() do
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
        :query_params => %{"last_checked_at" => {:cache, "timestamp"}},
        # Specify json response field mappings to provider fields
        :field_mappings => %{
          "driver" => "driver",
          "car" => "car",
          "created_at" => "created_at",
          "extra" => nil
        },
        # Specify endpoint url
        :url => "http://0.0.0.0:4000/feed/v1/ginzarides"
      }
    }
  end

  # kermit module name doesn't exist (hence doesn't implement behaviour)
  def manifest4() do
    %{
      :kermit => %{
        :active => false,
        :format => {:custom, Rides.Provider.NotImplemented},
        :key => "Green guy"
      }
    }
  end

  defmodule Gonzo do
    @behaviour Rides.Provider

    def new([]), do: IO.puts("Created Gonzo worker")

    def run(_, _sleep) do
      IO.puts("I'm too busy speeding! #{inspect(self())}")
    end

    def store(:ets, _data), do: :ok
  end

  defmodule Fonzee do
    @behaviour Rides.Provider

    def new([]), do: IO.puts("Created Fonzee worker")

    def run(_, _sleep) do
      IO.puts("Fonzee eating instead. Waka waka! #{inspect(self())}")
    end

    def store(:ets, _data), do: :ok
  end
end
