use Mix.Config

# For each provider, please add a manifest entry using an atom provider key name e.g. :ginza
# Please specify the required fields [:active, :format, :key, :field_mappings] if format :manifest

# Format
# For the :format value, please specify :manifest unless
# you plan to pass in a custom Module implementation which is denoted by for example
# {:custom, Rides.Provider.X}

# When the :manifest tag is used, we will create a provider worker given
# the metadata listed in that manifest entry

# Thus, when the :custom tuple tag is used it is assumed that a generic Provider Task won't
# be used but the custom Module implementation.  Hence the only required manifest entry keys
# are :active, :format and :key

# Field Mappings
# For the :field_mappings entry please list mappings for all the required fields 
# ["driver", "passenger", "created_at", "car", "extra"]

_ = """
Example manifest map

%{
  # Specify the provider manifest entry for FastBall
  :ginza => %{
    :active => true,
    :format => :manifest,
    # Key to store provider id alongside fetched rides data tuple
    :key => "GinzaRides",
    # Specify if any query params are used (as it is optional)
    # Specify how to obtain query param value either static value
    # or mapping to provider struct field name
    :query_params => %{"last_checked_at" => {@cache, "timestamp"}},
    # Specify json response field mappings to provider fields
    :field_mappings => %{
      "drive" => "driver",
      "passenger" => "passenger",
      "created_at" => "created_at",
      "car" => "car",
      "extra" => nil
    },
    # Specify endpoint url
    :url => "http://0.0.0.0:4000/feed/v1/ginzarides",
    # Specify optional de dup flag
    :dedup => true
  },
  # Specify the provider manifest entry for Kamakura
  :kamakura => %{
    :active => true,
    :format => :manifest,
    # Key to store provider id alongside fetched rides data tuple
    :key => "KamakuraShares",
    # Specify json response field mappings to provider fields
    :field_mappings => %{
      "driver" => {"occupants", &Helper.split_first/1},
      "passenger" => {"occupants", &Helper.split_last/1},
      "created_at" => "created_at",
      "car" => "car",
      "extra" => nil
    },
    # Specify endpoint url
    :url => "http://0.0.0.0:4000/feed/v1/kamakurashares"
  },

  # Specify the provider manifest entry for provider x, which uses custom implementation
  :provider_x => %{
    :active => true,
    # Define custom implementation
    :format => {:custom, Rides.Provider.X},
    # Key to store provider id alongside fetched rides data tuple
    :key => "Provider X Key"
  }
}
"""

config :rides,
  providers_manifest: %{
    # Specify the provider manifest entry for Kamukara
    :kamakura => %{
      :active => true,
      :format => :manifest,
      # Key to store provider id alongside fetched rides data tuple
      :key => "Kamakurashares",
      # Specify json response field mappings to provider fields
      :field_mappings => %{
        "driver" => {"occupants", &Rides.Manifest.Helper.split_first/1},
        "passenger" => {"occupants", &Rides.Manifest.Helper.split_last/1},
        "created_at" => "created_at",
        "car" => "car",
        "extra" => nil
      },
      # Specify endpoint url
      :url => "http://0.0.0.0:4000/feed/v1/kamakurashares",
      # Specify optional de duplication flag
      :dedup => true
    },

    # Specify the provider manifest entry for GinzaRides
    :ginza => %{
      :active => true,
      :format => :manifest,
      # Key to store provider id alongside fetched rides data tuple
      :key => "GinzaRides",
      # Specify if any query params are used (as it is optional)
      # Specify how to obtain query param value either static value
      # or mapping to provider struct field name
      :query_params => %{"last_checked_at" => {:cache, "timestamp"}},
      # Specify json response field mappings to provider fields
      :field_mappings => %{
        "driver" => "driver",
        "passenger" => "passenger",
        "created_at" => "created_at",
        "car" => "car",
        "extra" => nil
      },
      # Specify endpoint url
      :url => "http://0.0.0.0:4000/feed/v1/ginzarides"
    }
  }
