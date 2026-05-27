defmodule CaredeckWeb.LiveUserAuth do
  import Phoenix.Component, only: [assign: 3]

  def on_mount(:live_user_required, _params, _session, socket) do
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

  def on_mount(:live_team_required, _params, _session, socket) do
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

  def on_mount(:live_no_user, _params, _session, socket) do
    case socket.assigns[:current_user] do
      nil -> {:cont, assign(socket, :current_user, nil)}
      _user -> {:halt, Phoenix.LiveView.redirect(socket, to: "/feed")}
    end
  end

  def on_mount(:live_no_team, _params, _session, socket) do
    case socket.assigns[:current_team] do
      nil -> {:cont, assign(socket, :current_team, nil)}
      _team -> {:halt, Phoenix.LiveView.redirect(socket, to: "/feed")}
    end
  end

  def on_mount(:live_signed_in_optional, _params, _session, socket) do
    {:cont,
     socket
     |> assign_if_missing(:current_user, nil)
     |> assign_if_missing(:current_team, nil)}
  end

  defp assign_if_missing(socket, key, default) do
    if Map.has_key?(socket.assigns, key), do: socket, else: assign(socket, key, default)
  end
end
