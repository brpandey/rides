use Mix.Config

config :rides, ecto_repos: [Rides.Repo]

config :rides, Rides.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "rides_dev",
  username: System.get_env("DB_USER_NAME"),
  password: System.get_env("DB_USER_PASSWORD"),
  ownership_timeout: 50_000,
  pool: Ecto.Adapters.SQL.Sandbox

config :rides, Rides.Scheduler,
  jobs: [
    # runs dispatch every minute, we get every 30 secs by having an additional routine
    # get triggered on the minute edge, but sleeps for 30 seconds until it starts
    {"* * * * *", {Rides.Dispatcher, :fetch, [:minute_top, true]}},
    {"* * * * *", {Rides.Dispatcher, :fetch, [:minute_half, false]}},
    {"* * * * *", {Rides.Persister, :run, []}}
  ]

# to test run iex -S mix

# crontab format

# * * * * * *
# | | | | | | 
# | | | | | +-- Year              (range: 1900-3000)
# | | | | +---- Day of the Week   (range: 1-7, 1 standing for Monday)
# | | | +------ Month of the Year (range: 1-12)
# | | +-------- Day of the Month  (range: 1-31)
# | +---------- Hour              (range: 0-23)
# +------------ Minute            (range: 0-59)
