defmodule Rides do
  use Application
  require Logger

  @callback start(term, Keyword.t()) :: Supervisor.on_start()
  def start(_type, _args) do
    _ = Logger.debug("Starting Rides Application")
    Rides.Supervisor.start_link()
  end
end
