defmodule Rides.WorkerTest do
  use ExUnit.Case

  alias Rides.Worker

  # Note these field mappings have already been validated and 
  # run against the mapping resolver function hence they are inverted
  # when compared against the config entries

  @worker1 %Worker{
    field_mappings: %{
      "car" => "car",
      "created_at" => "created_at",
      "occupants" => [
        {"driver", &Rides.Manifest.Helper.split_first/1},
        {"passenger", &Rides.Manifest.Helper.split_last/1}
      ]
    },
    key: "Kamakurashares",
    query_params: nil,
    url: "http://0.0.0.0:4000/feed/v1/kamakurashares",
    dedup: false
  }

  @worker2 %Worker{
    field_mappings: %{
      "car" => "car",
      "passenger" => "passenger",
      "created_at" => "created_at",
      "driver" => "driver"
    },
    key: "GinzaRides",
    query_params: %{"last_checked_at" => {:cache, "timestamp"}},
    url: "http://0.0.0.0:4000/feed/v1/ginzarides",
    dedup: false
  }

  @worker3 %Worker{
    field_mappings: %{
      "car" => "car",
      "color" => :extra,
      "created_at" => "created_at",
      "mascot" => :extra,
      "occupants" => [
        {"driver", &Rides.Manifest.Helper.split_first/1},
        {"passenger", &Rides.Manifest.Helper.split_last/1}
      ]
    },
    key: "WakaWaka",
    query_params: nil,
    url: "http://0.0.0.0:4000/feed/v1/kamakurashares",
    dedup: false
  }

  @headers1 [
    {"cache-control", "max-age=0, private, must-revalidate"},
    {"content-length", "9999"},
    {"content-type", "application/json"},
    {"server", "Cowboy"}
  ]

  @headers2 [
    {"cache-control", "max-age=0, private, must-revalidate"},
    {"content-length", "9999"},
    {"content-type", "application/xml"},
    {"server", "Cowboy"}
  ]

  # response body for Kamakurashares
  @body1 "{\"rides\":[{\"car\":\"Toyota Prius\", \"created_at\":1522717157,\"occupants\":\"Cho - Hideki\"},{\"car\":\"Toyota Prius\", \"created_at\":1522717162,\"occupants\":\"Hoshi - Kasumi\"},{\"car\":\"Toyota Prius\", \"created_at\":1522717167,\"occupants\":\"Mitsuko - Nao\"},{\"car\":\"Toyota Prius\", \"created_at\":1522717172,\"occupants\":\"Hiromi - Kazuki\"},{\"car\":\"Toyota Prius\", \"created_at\":1522717177,\"occupants\":\"Kiyoshi - Mitsuko\"},{\"car\":\"Toyota Prius\", \"created_at\":1522717182,\"occupants\":\"Osamu - Satoshi\"},{\"car\":\"Toyota Prius\", \"created_at\":1522717187,\"occupants\":\"Hoshi - Suzu\"},{\"car\":\"Toyota Prius\", \"created_at\":1522717192,\"occupants\":\"Suzu - Jiro\"},{\"car\":\"Toyota Prius\", \"created_at\":1522717197,\"occupants\":\"Haru - Chikako\"},{\"car\":\"Toyota Prius\", \"created_at\":1522717202,\"occupants\":\"Harumi - Hoshi\"},{\"car\":\"Toyota Prius\", \"created_at\":1522717207,\"occupants\":\"Kimi - Eiji\"}]}"

  @processed_body1 [
    {"Cho", "Hideki", "Toyota Prius", 1_522_717_157, nil},
    {"Hoshi", "Kasumi", "Toyota Prius", 1_522_717_162, nil},
    {"Mitsuko", "Nao", "Toyota Prius", 1_522_717_167, nil},
    {"Hiromi", "Kazuki", "Toyota Prius", 1_522_717_172, nil},
    {"Kiyoshi", "Mitsuko", "Toyota Prius", 1_522_717_177, nil},
    {"Osamu", "Satoshi", "Toyota Prius", 1_522_717_182, nil},
    {"Hoshi", "Suzu", "Toyota Prius", 1_522_717_187, nil},
    {"Suzu", "Jiro", "Toyota Prius", 1_522_717_192, nil},
    {"Haru", "Chikako", "Toyota Prius", 1_522_717_197, nil},
    {"Harumi", "Hoshi", "Toyota Prius", 1_522_717_202, nil},
    {"Kimi", "Eiji", "Toyota Prius", 1_522_717_207, nil}
  ]

  # Response body for Ginzarides
  @body2 "{\"rides\":[{\"passenger\":\"Miwa\",\"car\":\"Toyota Prius\", \"created_at\":1522793270,\"driver\":\"Kokoro\"},{\"passenger\":\"Noboru\",\"car\":\"Toyota Prius\", \"created_at\":1522793275,\"driver\":\"Nana\"},{\"passenger\":\"Jiro\",\"car\":\"Toyota Prius\", \"created_at\":1522793280,\"driver\":\"Mizuki\"},{\"passenger\":\"Cho\",\"car\":\"Toyota Prius\", \"created_at\":1522793285,\"driver\":\"Hibiki\"},{\"passenger\":\"Atsushi\",\"car\":\"Toyota Prius\", \"created_at\":1522793290,\"driver\":\"Ayaka\"},{\"passenger\":\"Honoka\",\"car\":\"Toyota Prius\", \"created_at\":1522793295,\"driver\":\"Daichi\"},{\"passenger\":\"Jiro\",\"car\":\"Toyota Prius\", \"created_at\":1522793300,\"driver\":\"Chinatsu\"},{\"passenger\":\"Satoshi\",\"car\":\"Toyota Prius\", \"created_at\":1522793305,\"driver\":\"Arata\"},{\"passenger\":\"Shuji\",\"car\":\"Toyota Prius\", \"created_at\":1522793310,\"driver\":\"Osamu\"},{\"passenger\":\"Susumu\",\"car\":\"Toyota Prius\", \"created_at\":1522793315,\"driver\":\"Kimi\"},{\"passenger\":\"Hoshi\",\"car\":\"Toyota Prius\", \"created_at\":1522793320,\"driver\":\"Wakana\"}]}"

  @processed_body2 [
    {"Kokoro", "Miwa", "Toyota Prius", 1_522_793_270, nil},
    {"Nana", "Noboru", "Toyota Prius", 1_522_793_275, nil},
    {"Mizuki", "Jiro", "Toyota Prius", 1_522_793_280, nil},
    {"Hibiki", "Cho", "Toyota Prius", 1_522_793_285, nil},
    {"Ayaka", "Atsushi", "Toyota Prius", 1_522_793_290, nil},
    {"Daichi", "Honoka", "Toyota Prius", 1_522_793_295, nil},
    {"Chinatsu", "Jiro", "Toyota Prius", 1_522_793_300, nil},
    {"Arata", "Satoshi", "Toyota Prius", 1_522_793_305, nil},
    {"Osamu", "Shuji", "Toyota Prius", 1_522_793_310, nil},
    {"Kimi", "Susumu", "Toyota Prius", 1_522_793_315, nil},
    {"Wakana", "Hoshi", "Toyota Prius", 1_522_793_320, nil}
  ]

  # Response body with extra params color and mascot (originally Kamakurashares)
  @body3 "{\"rides\":[{\"color\":45,\"mascot\":\"lion\",\"car\":\"Toyota Prius\", \"created_at\":1522717157,\"occupants\":\"Cho - Hideki\"},{\"color\":46,\"mascot\":\"elephant\",\"car\":\"Toyota Prius\", \"created_at\":1522717162,\"occupants\":\"Hoshi - Kasumi\"},{\"color\":47,\"mascot\":\"monkey\",\"car\":\"Toyota Prius\", \"created_at\":1522717167,\"occupants\":\"Mitsuko - Nao\"},{\"color\":48,\"mascot\":\"cow\",\"car\":\"Toyota Prius\", \"created_at\":1522717172,\"occupants\":\"Hiromi - Kazuki\"},{\"color\":49,\"mascot\":\"zebra\",\"car\":\"Toyota Prius\", \"created_at\":1522717177,\"occupants\":\"Kiyoshi - Mitsuko\"},{\"color\":50,\"mascot\":\"mouse\",\"car\":\"Toyota Prius\", \"created_at\":1522717182,\"occupants\":\"Osamu - Satoshi\"},{\"color\":51,\"mascot\":\"emu\",\"car\":\"Toyota Prius\", \"created_at\":1522717187,\"occupants\":\"Hoshi - Suzu\"},{\"color\":52,\"mascot\":\"giraffe\",\"car\":\"Toyota Prius\", \"created_at\":1522717192,\"occupants\":\"Suzu - Jiro\"},{\"color\":53,\"mascot\":\"owl\",\"car\":\"Toyota Prius\", \"created_at\":1522717197,\"occupants\":\"Haru - Chikako\"},{\"color\":53,\"mascot\":\"snake\",\"car\":\"Toyota Prius\", \"created_at\":1522717202,\"occupants\":\"Harumi - Hoshi\"},{\"color\":54,\"mascot\":\"turtle\",\"car\":\"Toyota Prius\", \"created_at\":1522717207,\"occupants\":\"Kimi - Eiji\"}]}"

  @processed_body3 [
    {"Cho", "Hideki", "Toyota Prius", 1_522_717_157,
     <<130, 165, 99, 111, 108, 111, 114, 45, 166, 109, 97, 115, 99, 111, 116, 164, 108, 105, 111,
       110>>},
    {"Hoshi", "Kasumi", "Toyota Prius", 1_522_717_162,
     <<130, 165, 99, 111, 108, 111, 114, 46, 166, 109, 97, 115, 99, 111, 116, 168, 101, 108, 101,
       112, 104, 97, 110, 116>>},
    {"Mitsuko", "Nao", "Toyota Prius", 1_522_717_167,
     <<130, 165, 99, 111, 108, 111, 114, 47, 166, 109, 97, 115, 99, 111, 116, 166, 109, 111, 110,
       107, 101, 121>>},
    {"Hiromi", "Kazuki", "Toyota Prius", 1_522_717_172,
     <<130, 165, 99, 111, 108, 111, 114, 48, 166, 109, 97, 115, 99, 111, 116, 163, 99, 111, 119>>},
    {"Kiyoshi", "Mitsuko", "Toyota Prius", 1_522_717_177,
     <<130, 165, 99, 111, 108, 111, 114, 49, 166, 109, 97, 115, 99, 111, 116, 165, 122, 101, 98,
       114, 97>>},
    {"Osamu", "Satoshi", "Toyota Prius", 1_522_717_182,
     <<130, 165, 99, 111, 108, 111, 114, 50, 166, 109, 97, 115, 99, 111, 116, 165, 109, 111, 117,
       115, 101>>},
    {"Hoshi", "Suzu", "Toyota Prius", 1_522_717_187,
     <<130, 165, 99, 111, 108, 111, 114, 51, 166, 109, 97, 115, 99, 111, 116, 163, 101, 109, 117>>},
    {"Suzu", "Jiro", "Toyota Prius", 1_522_717_192,
     <<130, 165, 99, 111, 108, 111, 114, 52, 166, 109, 97, 115, 99, 111, 116, 167, 103, 105, 114,
       97, 102, 102, 101>>},
    {"Haru", "Chikako", "Toyota Prius", 1_522_717_197,
     <<130, 165, 99, 111, 108, 111, 114, 53, 166, 109, 97, 115, 99, 111, 116, 163, 111, 119, 108>>},
    {"Harumi", "Hoshi", "Toyota Prius", 1_522_717_202,
     <<130, 165, 99, 111, 108, 111, 114, 53, 166, 109, 97, 115, 99, 111, 116, 165, 115, 110, 97,
       107, 101>>},
    {"Kimi", "Eiji", "Toyota Prius", 1_522_717_207,
     <<130, 165, 99, 111, 108, 111, 114, 54, 166, 109, 97, 115, 99, 111, 116, 166, 116, 117, 114,
       116, 108, 101>>}
  ]

  @decoded_extras [
    %{"color" => 45, "mascot" => "lion"},
    %{"color" => 46, "mascot" => "elephant"},
    %{"color" => 47, "mascot" => "monkey"},
    %{"color" => 48, "mascot" => "cow"},
    %{"color" => 49, "mascot" => "zebra"},
    %{"color" => 50, "mascot" => "mouse"},
    %{"color" => 51, "mascot" => "emu"},
    %{"color" => 52, "mascot" => "giraffe"},
    %{"color" => 53, "mascot" => "owl"},
    %{"color" => 53, "mascot" => "snake"},
    %{"color" => 54, "mascot" => "turtle"}
  ]

  test "test kamakurashares w/o a network request but with a pre-supplied response" do
    assert @processed_body1 == Worker.run(@worker1, &fetch1/1)
  end

  test "test ginzarides w/o a network request but with a pre-supplied response" do
    assert @processed_body2 == Worker.run(@worker2, &fetch2/1)
  end

  test "test kamakurashares w/o a network request but with a pre-supplied response including extra fields" do
    assert @processed_body3 == Worker.run(@worker3, &fetch3/1)

    # quick verify to ensure the serialized lob field was properly constructed
    Enum.map(Enum.zip(@processed_body3, @decoded_extras), fn {{_ht, _at, _c, _ca, slob}, term} ->
      assert term == Msgpax.unpack!(slob)
    end)
  end

  test "test kamakurashares w/o a network request but with a pre-supplied response with unsupported headers" do
    assert [] == Worker.run(@worker1, &fetch4/1)
  end

  def fetch1(%Worker{}), do: {@headers1, @body1}
  def fetch2(%Worker{}), do: {@headers1, @body2}
  def fetch3(%Worker{}), do: {@headers1, @body3}
  def fetch4(%Worker{}), do: {@headers2, @body1}
end
