defmodule CaredeckWeb.HealthController do
  use CaredeckWeb, :controller

  def index(conn, _params) do
    conn = put_resp_content_type(conn, "text/plain")

    case Ecto.Adapters.SQL.query(Caredeck.Repo, "SELECT 1", []) do
      {:ok, _} -> send_resp(conn, 200, "ok")
      _ -> send_resp(conn, 503, "db unreachable")
    end
  end
end
