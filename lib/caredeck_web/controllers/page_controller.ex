defmodule CaredeckWeb.PageController do
  use CaredeckWeb, :controller

  def root(conn, _params) do
    cond do
      conn.assigns[:current_user] -> redirect(conn, to: ~p"/feed")
      conn.assigns[:current_team_identity] -> redirect(conn, to: ~p"/feed")
      true -> redirect(conn, to: ~p"/sign-in")
    end
  end
end
