defmodule Caredeck.Repo do
  use Ecto.Repo,
    otp_app: :caredeck,
    adapter: Ecto.Adapters.Postgres
end
