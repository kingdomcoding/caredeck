defmodule CaredeckWeb.DemoSignInController do
  use CaredeckWeb, :controller

  alias Caredeck.Accounts.{TeamIdentity, User}

  require Ash.Query

  def admin(conn, _), do: sign_in_team(conn, "team-admin", ~p"/formfix/admin")
  def care(conn, _), do: sign_in_team(conn, "team-care", ~p"/feed")
  def relative(conn, _), do: sign_in_user(conn, "demo-relative@example.test", ~p"/feed")

  defp sign_in_team(conn, handle, destination) do
    case TeamIdentity
         |> Ash.Query.filter(handle == ^handle)
         |> Ash.read_one(authorize?: false) do
      {:ok, %TeamIdentity{} = team} ->
        finish(conn, team, destination)

      _ ->
        unseeded(conn)
    end
  end

  defp sign_in_user(conn, email, destination) do
    case User
         |> Ash.Query.filter(email == ^email)
         |> Ash.read_one(authorize?: false) do
      {:ok, %User{} = user} ->
        finish(conn, user, destination)

      _ ->
        unseeded(conn)
    end
  end

  defp finish(conn, record, destination) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(record)
    record_with_token = %{record | __metadata__: Map.put(record.__metadata__, :token, token)}

    conn
    |> AshAuthentication.Plug.Helpers.store_in_session(record_with_token)
    |> redirect(to: destination)
  end

  defp unseeded(conn) do
    conn
    |> put_flash(:error, "Demo accounts not seeded — run Caredeck.Release.seed().")
    |> redirect(to: ~p"/sign-in")
  end
end
