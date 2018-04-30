defmodule Rides.Repo do
  # Injects the Ecto Repo functions into the Rides Repo
  use Ecto.Repo, otp_app: :rides
end
