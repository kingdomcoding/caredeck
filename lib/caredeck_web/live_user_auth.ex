defmodule CaredeckWeb.LiveUserAuth do
  import Phoenix.Component, only: [assign: 3, assign_new: 3]

  require Ash.Query

  def on_mount(:live_user_required, _params, session, socket) do
    socket = resolve(socket, session)

    case socket.assigns[:current_user] do
      nil ->
        {:halt,
         socket
         |> Phoenix.LiveView.put_flash(:error, "Please sign in to continue.")
         |> Phoenix.LiveView.redirect(to: "/sign-in")}

      _user ->
        {:cont, socket}
    end
  end

  def on_mount(:live_team_required, _params, session, socket) do
    socket = resolve(socket, session)

    case socket.assigns[:current_team] do
      nil ->
        {:halt,
         socket
         |> Phoenix.LiveView.put_flash(:error, "Sign in with a team account.")
         |> Phoenix.LiveView.redirect(to: "/team/sign-in")}

      _team ->
        {:cont, socket}
    end
  end

  def on_mount(:live_team_admin_required, _params, session, socket) do
    socket = resolve(socket, session)
    team = socket.assigns[:current_team]

    cond do
      is_nil(team) ->
        {:halt,
         socket
         |> Phoenix.LiveView.put_flash(:error, "Sign in with an admin account.")
         |> Phoenix.LiveView.redirect(to: "/team/sign-in")}

      team.role_kind != :admin ->
        {:halt,
         socket
         |> Phoenix.LiveView.put_flash(:error, "Admin access required.")
         |> Phoenix.LiveView.redirect(to: "/")}

      true ->
        {:cont, socket}
    end
  end

  def on_mount(:live_no_user, _params, session, socket) do
    socket = resolve(socket, session)

    case socket.assigns[:current_user] do
      nil -> {:cont, socket}
      _user -> {:halt, Phoenix.LiveView.redirect(socket, to: "/feed")}
    end
  end

  def on_mount(:live_no_team, _params, session, socket) do
    socket = resolve(socket, session)

    case socket.assigns[:current_team] do
      nil -> {:cont, socket}
      _team -> {:halt, Phoenix.LiveView.redirect(socket, to: "/feed")}
    end
  end

  def on_mount(:live_signed_in_optional, _params, session, socket) do
    {:cont, resolve(socket, session)}
  end

  def on_mount(:live_user_or_team_required, _params, session, socket) do
    socket = resolve(socket, session)

    cond do
      socket.assigns[:current_user] ->
        {:cont, socket}

      socket.assigns[:current_team] ->
        {:cont, socket}

      true ->
        {:halt,
         socket
         |> Phoenix.LiveView.put_flash(:error, "Please sign in to continue.")
         |> Phoenix.LiveView.redirect(to: "/sign-in")}
    end
  end

  defp resolve(socket, session) do
    socket
    |> AshAuthentication.Plug.Helpers.assign_new_resources(
      session,
      &Phoenix.Component.assign_new/3,
      otp_app: :caredeck
    )
    |> alias_assigns()
  end

  defp alias_assigns(socket) do
    socket =
      socket
      |> assign_new(:current_user, fn -> nil end)
      |> assign(:current_team, socket.assigns[:current_team_identity])

    assign(socket, :current_facility, resolve_facility(socket))
  end

  defp resolve_facility(socket) do
    cond do
      team = socket.assigns[:current_team] ->
        lookup_facility(team.facility_id)

      user = socket.assigns[:current_user] ->
        first_facility_for_user(user.id)

      true ->
        nil
    end
  end

  defp lookup_facility(nil), do: nil

  defp lookup_facility(facility_id) do
    case Ash.get(Caredeck.Org.Facility, facility_id, authorize?: false) do
      {:ok, facility} -> facility
      _ -> nil
    end
  end

  defp first_facility_for_user(user_id) do
    case Ash.read_one(
           Caredeck.Org.FacilityMembership
           |> Ash.Query.filter(user_id == ^user_id)
           |> Ash.Query.load(:facility),
           authorize?: false
         ) do
      {:ok, %{facility: facility}} -> facility
      _ -> nil
    end
  end
end
