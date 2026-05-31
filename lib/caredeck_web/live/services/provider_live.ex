defmodule CaredeckWeb.Services.ProviderLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Services.{ProviderKind, ServiceProvider, ServiceRequest}

  require Ash.Query

  @impl true
  def mount(%{"provider_id" => pid}, _session, socket) do
    facility = socket.assigns[:current_facility]
    actor = current_actor(socket)

    cond do
      is_nil(facility) ->
        {:ok, push_navigate(socket, to: ~p"/feed")}

      true ->
        case Ash.get(ServiceProvider, pid, tenant: facility.id, actor: actor) do
          {:ok, provider} ->
            requests = load_requests(facility, actor, pid)

            {:ok,
             socket
             |> assign(:page_title, provider.name)
             |> assign(:provider, provider)
             |> assign(:requests, requests)}

          _ ->
            {:ok, push_navigate(socket, to: ~p"/services")}
        end
    end
  end

  defp current_actor(socket),
    do: socket.assigns[:current_team] || socket.assigns[:current_user]

  defp load_requests(facility, actor, provider_id) do
    ServiceRequest
    |> Ash.Query.filter(provider_id == ^provider_id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(20)
    |> Ash.read!(tenant: facility.id, actor: actor)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-3xl px-4 sm:px-6 py-6">
        <header class="flex items-start justify-between gap-3 flex-wrap mb-6">
          <div>
            <p class="text-ink-500 text-xs uppercase tracking-wide">
              {ProviderKind.label(@provider.kind)}
            </p>
            <h1 class="text-display-md text-ink-900">{@provider.name}</h1>
            <p :if={@provider.response_window_label} class="text-ink-500 text-sm">
              {@provider.response_window_label}
            </p>
          </div>

          <.link
            navigate={~p"/services/#{@provider.id}/new"}
            class="rounded-button bg-brand text-white text-sm font-medium px-4 py-2 hover:bg-brand-strong"
          >
            New request &rarr;
          </.link>
        </header>

        <section class="bg-card rounded-card shadow-card p-4 mb-6 grid gap-3 sm:grid-cols-3 text-sm">
          <div>
            <p class="text-ink-500 text-xs uppercase tracking-wide">Address</p>
            <p class="text-ink-900">Demo Allee 12 · Berlin</p>
          </div>
          <div>
            <p class="text-ink-500 text-xs uppercase tracking-wide">Contact</p>
            <p class="text-ink-900">+49 30 0000 0000</p>
          </div>
          <div>
            <p class="text-ink-500 text-xs uppercase tracking-wide">Next visit</p>
            <p class="text-ink-900">{provider_next_visit(@provider.kind)}</p>
          </div>
        </section>

        <h2 class="text-ink-900 font-medium mb-2">Recent requests</h2>

        <p :if={@requests == []} class="text-ink-500 text-sm text-center py-12 bg-card rounded-card">
          No requests yet.
        </p>

        <ul
          :if={@requests != []}
          class="bg-card rounded-card shadow-card divide-y divide-divider overflow-hidden"
        >
          <li :for={r <- @requests}>
            <.link navigate={~p"/services/requests/#{r.id}"} class="block px-4 py-3 hover:bg-page">
              <div class="flex items-center justify-between gap-2 flex-wrap">
                <p class="text-ink-900 font-medium">{r.summary || r.subkind}</p>
                <.state_pill state={r.state} />
              </div>
              <p class="text-ink-500 text-xs mt-1">
                {Calendar.strftime(r.inserted_at, "%d %b %Y · %H:%M")}
              </p>
            </.link>
          </li>
        </ul>
      </div>
    </Layouts.app>
    """
  end

  attr :state, :atom, required: true

  defp state_pill(assigns) do
    ~H"""
    <span class={[
      "text-xs font-medium rounded-full px-2 py-0.5",
      @state == :open && "bg-brand-soft text-brand",
      @state == :in_progress && "bg-yellow-100 text-yellow-700",
      @state == :resolved && "bg-green-100 text-green-700",
      @state == :cancelled && "bg-page text-ink-500"
    ]}>
      {humanize_state(@state)}
    </span>
    """
  end

  defp humanize_state(:open), do: "Open"
  defp humanize_state(:in_progress), do: "In progress"
  defp humanize_state(:resolved), do: "Resolved"
  defp humanize_state(:cancelled), do: "Cancelled"

  defp provider_next_visit(:doctor), do: "Mon · 10:00"
  defp provider_next_visit(:pharmacy), do: "Daily delivery"
  defp provider_next_visit(:hairdresser), do: "Thu · 13:00"
  defp provider_next_visit(:laundry), do: "Tue + Fri"
  defp provider_next_visit(_), do: "On request"
end
