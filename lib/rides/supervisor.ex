defmodule Rides.Supervisor do
  @moduledoc """
  Top line supervisor
  Overseas Task Supervisor responsible for overseeing provider worker bees
  Overseas GenServer Cache ETS owning process
  Overseas Scheduler and Repo supervisor/workers

  all using one for one (no real relationship between processes for now e.g. rest for one)
  """

  use Supervisor

  @doc "Client method to invoke Supervisor process instantiation"
  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc "Callback to setup initial supervisor state"
  def init(:ok) do
    children = [
      supervisor(Task.Supervisor, [[name: Rides.Worker.Supervisor]]),
      worker(Rides.Repo, []),
      worker(Rides.Scheduler, []),
      worker(Rides.Cache, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
