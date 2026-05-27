defmodule CaredeckWeb.TeamAuthController do
  use CaredeckWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, _activity, team, token) do
    team_with_token =
      if token, do: Map.update!(team, :__metadata__, &Map.put(&1, :token, token)), else: team

    conn
    |> store_in_session(team_with_token)
    |> put_session(:current_facility_id, team.facility_id)
    |> assign(:current_team, team)
    |> put_flash(:info, "Signed in as #{team.name}.")
    |> redirect(to: "/feed")
  end

  def failure(conn, _activity, _reason) do
    conn
    |> put_flash(:error, "Sign-in failed. Check the handle and password.")
    |> redirect(to: "/team/sign-in")
  end

  def sign_out(conn, _params) do
    conn
    |> clear_session(:caredeck)
    |> put_flash(:info, "Signed out.")
    |> redirect(to: "/team/sign-in")
  end
end
