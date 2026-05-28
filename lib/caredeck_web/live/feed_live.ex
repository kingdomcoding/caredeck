defmodule CaredeckWeb.FeedLive do
  use CaredeckWeb, :live_view

  alias Caredeck.People.Resident
  alias Caredeck.Tenancy

  @impl true
  def mount(_params, _session, socket) do
    facility = socket.assigns[:current_facility]

    residents =
      if facility do
        Resident
        |> Ash.read!(tenant: Tenancy.to_tenant(facility), authorize?: false)
        |> Enum.sort_by(&{&1.last_name, &1.first_name})
      else
        []
      end

    {:ok,
     socket
     |> assign(:page_title, "Feed")
     |> assign(:residents, residents)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-3xl px-6 py-12">
        <h1 class="text-display-md text-ink-900 mb-2">Feed</h1>
        <p class="text-ink-500 mb-8">
          Signed in to
          <span class="text-ink-900 font-medium">
            {if @current_facility, do: @current_facility.name, else: "no facility"}
          </span>
        </p>

        <section class="bg-card rounded-card shadow-card p-6">
          <h2 class="text-display-sm text-ink-900 mb-4">
            Residents ({length(@residents)})
          </h2>

          <ul :if={@residents != []} class="divide-y divide-divider">
            <li :for={resident <- @residents} class="py-3 flex items-center justify-between">
              <div>
                <p class="text-ink-900 font-medium">
                  {resident.first_name} {resident.last_name}
                </p>
                <p class="text-ink-500 text-sm">
                  <%= if resident.date_of_birth do %>
                    Born {Calendar.strftime(resident.date_of_birth, "%B %Y")}
                  <% else %>
                    Birth date unknown
                  <% end %>
                </p>
              </div>
              <span class={[
                "inline-flex items-center px-3 py-1 text-xs font-medium rounded-chip border",
                lifecycle_classes(resident.lifecycle_state)
              ]}>
                {lifecycle_label(resident.lifecycle_state)}
              </span>
            </li>
          </ul>

          <p :if={@residents == []} class="text-ink-500 text-sm">
            No residents visible.
          </p>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp lifecycle_classes(:admitted),
    do: "bg-status-approved-bg border-status-approved-border text-status-approved-text"

  defp lifecycle_classes(:discharged),
    do: "bg-status-ready-bg border-status-ready-border text-status-ready-text"

  defp lifecycle_classes(:deceased),
    do: "bg-status-draft-bg border-status-draft-border text-status-draft-text"

  defp lifecycle_label(:admitted), do: "Admitted"
  defp lifecycle_label(:discharged), do: "Discharged"
  defp lifecycle_label(:deceased), do: "Deceased"
end
