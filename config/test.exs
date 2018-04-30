use Mix.Config

config :rides, ecto_repos: [Rides.Repo]

config :rides, Rides.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "rides_test",
  username: System.get_env("DB_USER_NAME"),
  password: System.get_env("DB_USER_PASSWORD"),
  ownership_timeout: 50_000,
  pool: Ecto.Adapters.SQL.Sandbox

config :rides, Rides.Scheduler,
  jobs: [
    # to test run: iex -S mix test
    # {"* * * * *", {Rides.Dispatcher, :fetch, [:minute_top, true]}},
    {"* * * * *", {Rides.Dispatcher, :fetch, [:minute_half, false]}}

    #    {"5 * * * *", {IO, :puts, ["Greetings"]}}
  ]
