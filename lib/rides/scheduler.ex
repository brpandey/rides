defmodule Rides.Scheduler do
  # Injects the Quantum scheduler functions into the Rides app
  # Enable Quantum cron like functionality
  use Quantum.Scheduler, otp_app: :rides
end
