defmodule CaredeckWeb.Services.InboxLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Services.ServiceRequest

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    facility = socket.assigns[:current_facility]

    cond do
      is_nil(facility) ->
        {:ok, push_navigate(socket, to: ~p"/feed")}

      not allowed?(socket) ->
        {:ok, push_navigate(socket, to: ~p"/services")}

      true ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(
            Caredeck.PubSub,
            "services:inbox:#{facility.id}"
          )
        end

        {:ok,
         socket
         |> assign(:page_title, "Services inbox")
         |> assign(:requests, load_open_requests(facility))}
    end
  end

  defp allowed?(socket) do
    team = socket.assigns[:current_team]
    team && team.role_kind in [:care, :service, :admin]
  end

  defp load_open_requests(facility) do
    ServiceRequest
    |> Ash.Query.filter(state in [:open, :in_progress])
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.load([:provider, :resident])
    |> Ash.read!(tenant: facility.id, authorize?: false)
  end

  @impl true
  def handle_info(_, socket),
    do: {:noreply, assign(socket, :requests, load_open_requests(socket.assigns.current_facility))}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-4xl px-4 sm:px-6 py-6">
        <h1 class="text-display-md text-ink-900 mb-6">Services inbox</h1>

        <p :if={@requests == []} class="text-ink-500 text-sm">
          No open requests right now.
        </p>

        <ul
          :if={@requests != []}
          class="bg-card rounded-card shadow-card divide-y divide-divider"
        >
          <li :for={r <- @requests}>
            <.link navigate={~p"/services/requests/#{r.id}"} class="block px-4 py-3 hover:bg-page">
              <div class="flex items-center justify-between gap-2 flex-wrap">
                <p class="text-ink-900 font-medium">{r.summary || r.subkind}</p>
                <span class="text-ink-500 text-xs uppercase tracking-wide">
                  {r.provider.name}
                </span>
              </div>
              <p :if={r.resident} class="text-ink-500 text-xs mt-0.5">
                Resident: {r.resident.first_name} {r.resident.last_name}
              </p>
            </.link>
          </li>
        </ul>
      </div>
    </Layouts.app>
    """
  end
end
