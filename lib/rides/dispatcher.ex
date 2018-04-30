defmodule Rides.Dispatcher do
  @moduledoc """
  Module provides support for fetching rides in parallel
  Supports ability to slightly stagger execution of workers
  Runs workers on the start of the minute and the half minute

  Since cron can only do increments of a minute
  We have cron trigger the two fetch routines at the same time,
  with the second sleeping 30 seconds
  """

  require Logger
  alias Rides.{Worker.Supervisor, Worker}
  alias Rides.Manifest

  # Load the static providers
  @providers Manifest.load()

  # Dispatch every thirty seconds, convert into milliseconds
  @frequency 30 * 1000

  # Use milliseconds -- up to the first 1/2 sec mark
  # Clearly we want the data to be fetched to be fast
  # but let's make sure every provider is not hitting the network
  # at the same time
  # Hence we use the first @stagger_upper ms of the 30 second time window to 
  # issue our requests staggering within the first second..

  @stagger_upper 1 * 200

  # stagger intervals
  @stagger 0..@stagger_upper |> Enum.into([])

  @no_stagger Stream.cycle([0]) |> Enum.take(@stagger_upper)

  @doc "Runs workers at top of the minute"
  def fetch(:minute_top, stagger) when is_boolean(stagger) do
    run(stagger)
  end

  @doc """
  Runs workers at the half minute mark
  """
  def fetch(:minute_half, stagger) when is_boolean(stagger) do
    Process.sleep(@frequency)
    run(stagger)
  end

  @doc "Run function which sets up the run staggering"
  def run(true) do
    # Ensure we get new random shuffle results every time run is invoked
    seed_random()

    run(@providers, @stagger)
  end

  @doc "Run function with no staggering"
  def run(false), do: run(@providers, @no_stagger)

  @doc """
  Core run function which takes a list of the provider representations and runs them in parallel via Tasks
  """
  def run(providers, stagger) when is_list(providers) and is_list(stagger) do
    staggered_starts = Enum.shuffle(stagger) |> Stream.cycle()
    zipped = Enum.zip(providers, staggered_starts)

    # Parallel each 
    # Note: We are more interested in the side effects, otherwise it would be Parallel map
    # The run function performs a network request and cache write

    # Using a task instead of doing a Kernel.spawn
    # Task/TaskSupervisor has better introspection / debugging support
    # Also supports distributed nodes

    # Also, will link to the created task, assumes task is temporary, and handles task cleanup better than spawn

    # This also saves from having to do an await in this client code 
    # as it is already handled by the supervisor

    Enum.each(zipped, fn {provider, start_time} -> start(provider, start_time) end)
  end

  # Run start routine pattern mattched for template worker module
  # Since run through Supervisor no need to link to current process
  defp start(%Worker{} = w, start_time) do
    Task.Supervisor.async_nolink(Supervisor, Worker, :run, [w, start_time])
  end

  # Run start routine pattern mattched for custom implementation worker module
  # Since run through Supervisor no need to link to current process
  defp start({module, worker}, start_time) do
    Task.Supervisor.async_nolink(Supervisor, module, :run, [worker, start_time])
  end

  # seed random number generator with random seed
  defp seed_random() do
    <<a::32, b::32, c::32>> = :crypto.strong_rand_bytes(12)
    r_seed = {a, b, c}

    _ = :rand.seed(:exsplus, r_seed)
    _ = :rand.seed(:exsplus, r_seed)
  end
end
