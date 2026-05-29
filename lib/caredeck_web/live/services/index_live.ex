defmodule CaredeckWeb.Services.IndexLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Services.{ProviderKind, ServiceProvider}

  @impl true
  def mount(_params, _session, socket) do
    facility = socket.assigns[:current_facility]
    providers = list_providers(facility)

    {:ok,
     socket
     |> assign(:page_title, "Services")
     |> assign(:providers, providers)}
  end

  defp list_providers(nil), do: []

  defp list_providers(facility) do
    ServiceProvider
    |> Ash.Query.sort(kind: :asc)
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
                <span class="h-10 w-10 rounded-full bg-brand-soft text-brand flex items-center justify-center text-lg">
                  {kind_emoji(p.kind)}
                </span>
                <div>
                  <p class="text-ink-900 font-medium">{p.name}</p>
                  <p class="text-ink-500 text-xs uppercase tracking-wide">
                    {ProviderKind.label(p.kind)}
                  </p>
                </div>
              </div>
              <p :if={p.response_window_label} class="text-ink-500 text-xs">
                Hours: {p.response_window_label}
              </p>
            </.link>
          </li>
        </ul>
      </div>
    </Layouts.app>
    """
  end

  defp kind_emoji(:pharmacy), do: "💊"
  defp kind_emoji(:laundry), do: "🧺"
  defp kind_emoji(:podiatry), do: "🦶"
  defp kind_emoji(:hairdresser), do: "✂"
  defp kind_emoji(:doctor), do: "🩺"
  defp kind_emoji(:physio), do: "🤸"
  defp kind_emoji(:florist), do: "💐"
end
