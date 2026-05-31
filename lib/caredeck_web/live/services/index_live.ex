defmodule CaredeckWeb.Services.IndexLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Services.{ProviderKind, ServiceProvider, ServiceRequest}

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    facility = socket.assigns[:current_facility]
    providers = list_providers(facility)
    open_counts = open_request_counts(facility)
    recent = recent_requests(facility)

    {:ok,
     socket
     |> assign(:page_title, "Services")
     |> assign(:providers, providers)
     |> assign(:open_counts, open_counts)
     |> assign(:recent_requests, recent)}
  end

  defp list_providers(nil), do: []

  defp list_providers(facility) do
    ServiceProvider
    |> Ash.Query.sort(kind: :asc)
    |> Ash.read!(tenant: facility.id, authorize?: false)
  end

  defp open_request_counts(nil), do: %{}

  defp open_request_counts(facility) do
    ServiceRequest
    |> Ash.Query.filter(state in [:open, :in_progress])
    |> Ash.read!(tenant: facility.id, authorize?: false)
    |> Enum.frequencies_by(& &1.provider_id)
  end

  defp recent_requests(nil), do: []

  defp recent_requests(facility) do
    ServiceRequest
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(5)
    |> Ash.Query.load([:provider])
    |> Ash.read!(tenant: facility.id, authorize?: false)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-5xl px-4 sm:px-6 py-6">
        <h1 class="text-display-md text-ink-900 mb-6">Services</h1>

        <p :if={@providers == []} class="text-ink-500 text-sm">
          No service providers are configured for this facility yet.
        </p>

        <ul
          :if={@providers != []}
          class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3"
        >
          <li :for={p <- @providers}>
            <.link
              navigate={~p"/services/#{p.id}"}
              class="block bg-card rounded-card shadow-card p-5 hover:border-brand border border-transparent transition"
            >
              <div class="flex items-center gap-3 mb-2">
                <span class="h-10 w-10 rounded-full bg-brand-soft text-brand flex items-center justify-center">
                  <Icons.icon name={kind_icon(p.kind)} class="h-5 w-5" />
                </span>
                <div>
                  <p class="text-ink-900 font-medium">{p.name}</p>
                  <p class="text-ink-500 text-xs uppercase tracking-wide">
                    {ProviderKind.label(p.kind)}
                  </p>
                </div>
                <span
                  :if={Map.get(@open_counts, p.id, 0) > 0}
                  class="ml-auto rounded-full bg-yellow-100 text-yellow-800 text-xs font-medium px-2 py-0.5"
                >
                  {Map.get(@open_counts, p.id)} open
                </span>
              </div>
              <p :if={p.response_window_label} class="text-ink-500 text-xs">
                Hours: {p.response_window_label}
              </p>
            </.link>
          </li>
        </ul>

        <section :if={@recent_requests != []} class="mt-10">
          <h2 class="text-ink-500 text-xs uppercase tracking-wide mb-2">
            Recent requests
          </h2>
          <ul class="bg-card rounded-card shadow-card divide-y divide-divider">
            <li :for={r <- @recent_requests}>
              <.link
                navigate={~p"/services/requests/#{r.id}"}
                class="flex items-center justify-between gap-2 px-4 py-3 hover:bg-page"
              >
                <div>
                  <p class="text-ink-900 text-sm font-medium">
                    {r.summary || r.subkind || "Service request"}
                  </p>
                  <p class="text-ink-500 text-xs">
                    {r.provider.name} · {Calendar.strftime(r.inserted_at, "%d %b")}
                  </p>
                </div>
                <span class="text-ink-500 text-xs uppercase tracking-wide">{r.state}</span>
              </.link>
            </li>
          </ul>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp kind_icon(:pharmacy), do: :pill
  defp kind_icon(:laundry), do: :basket
  defp kind_icon(:podiatry), do: :foot
  defp kind_icon(:hairdresser), do: :scissors
  defp kind_icon(:doctor), do: :stethoscope
  defp kind_icon(:physio), do: :sparkle
  defp kind_icon(:florist), do: :flower
  defp kind_icon(_), do: :stethoscope
end
