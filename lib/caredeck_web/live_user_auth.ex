defmodule CaredeckWeb.LiveUserAuth do
  import Phoenix.Component, only: [assign: 3, assign_new: 3]

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
    socket
    |> assign_new(:current_user, fn -> nil end)
    |> assign(:current_team, socket.assigns[:current_team_identity])
  end
end
