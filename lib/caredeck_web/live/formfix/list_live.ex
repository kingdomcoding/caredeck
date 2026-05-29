defmodule CaredeckWeb.Formfix.ListLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Formfix.Application, as: AidApplication
  alias Caredeck.Formfix.Applications
  alias Caredeck.People.{Relative, RelativeOfResident, Resident}

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    facility = socket.assigns[:current_facility]
    actor = current_actor(socket)

    applications = load_applications(facility, actor)
    residents_available = scoped_residents(facility, socket.assigns[:current_user])

    {:ok,
     socket
     |> assign(:page_title, "Formfix")
     |> assign(:applications, applications)
     |> assign(:residents_available, residents_available)
     |> assign(:picking_resident, false)
     |> assign(:resident_id, residents_available |> List.first() |> then(&(&1 && &1.id)))}
  end

  defp current_actor(socket),
    do: socket.assigns[:current_team] || socket.assigns[:current_user]

  defp load_applications(nil, _), do: []

  defp load_applications(facility, actor) do
    AidApplication
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.load([:resident, :progress_percent])
    |> Ash.read!(tenant: facility.id, actor: actor)
  end

  defp scoped_residents(_facility, nil), do: []

  defp scoped_residents(facility, user) do
    relative_ids =
      Relative
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.read!(tenant: facility.id, authorize?: false)
      |> Enum.map(& &1.id)

    case relative_ids do
      [] ->
        []

      ids ->
        resident_ids =
          RelativeOfResident
          |> Ash.Query.filter(relative_id in ^ids)
          |> Ash.read!(tenant: facility.id, authorize?: false)
          |> Enum.map(& &1.resident_id)
          |> Enum.uniq()

        Resident
        |> Ash.Query.filter(id in ^resident_ids and lifecycle_state == :admitted)
        |> Ash.Query.sort(last_name: :asc)
        |> Ash.read!(tenant: facility.id, authorize?: false)
    end
  end

  @impl true
  def handle_event("pick_resident", _, socket),
    do: {:noreply, assign(socket, :picking_resident, true)}

  def handle_event("set_resident", %{"resident_id" => rid}, socket),
    do: {:noreply, assign(socket, :resident_id, rid)}

  def handle_event("start", _, socket) do
    facility = socket.assigns.current_facility
    actor = current_actor(socket)
    rid = socket.assigns.resident_id

    {:ok, resident} = Ash.get(Resident, rid, tenant: facility.id, authorize?: false)
    app = Applications.start_for_resident!(facility, resident, actor)

    {:noreply, push_navigate(socket, to: ~p"/formfix/#{app.id}/overview")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-4xl px-4 sm:px-6 py-6">
        <header class="flex items-center justify-between gap-3 flex-wrap mb-6">
          <h1 class="text-display-md text-ink-900">Formfix</h1>

          <button
            :if={@residents_available != []}
            type="button"
            phx-click="pick_resident"
            class="rounded-button bg-brand text-white text-sm font-medium px-4 py-2 hover:bg-brand-strong"
          >
            Start new application
          </button>
        </header>

        <form
          :if={@picking_resident}
          phx-change="set_resident"
          phx-submit="start"
          class="bg-card rounded-card shadow-card p-4 mb-6 space-y-3"
        >
          <label class="block">
            <span class="text-ink-900 text-sm font-medium">For which resident?</span>
            <select
              name="resident_id"
              class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
            >
              <option :for={r <- @residents_available} value={r.id} selected={@resident_id == r.id}>
                {r.first_name} {r.last_name}
              </option>
            </select>
          </label>
          <button
            type="submit"
            class="rounded-button bg-brand text-white px-4 py-2 text-sm font-medium"
          >
            Open new application
          </button>
        </form>

        <p
          :if={@applications == []}
          class="text-ink-500 text-sm text-center py-12 bg-card rounded-card"
        >
          No applications yet.
        </p>

        <ul
          :if={@applications != []}
          class="bg-card rounded-card shadow-card divide-y divide-divider overflow-hidden"
        >
          <li :for={a <- @applications}>
            <.link navigate={~p"/formfix/#{a.id}/overview"} class="block px-4 py-3 hover:bg-page">
              <div class="flex items-center justify-between gap-2 flex-wrap">
                <p class="text-ink-900 font-medium">
                  Application for {a.resident.first_name} {a.resident.last_name}
                </p>
                <.formfix_status_pill status={a.state} />
              </div>
              <div class="mt-2 h-2 w-full bg-page rounded-full overflow-hidden">
                <div class="h-2 bg-brand" style={"width: #{a.progress_percent}%"}></div>
              </div>
              <p class="text-ink-500 text-xs mt-1">
                {a.progress_percent}% complete · updated {Calendar.strftime(a.updated_at, "%d %b %Y")}
              </p>
            </.link>
          </li>
        </ul>

        <.formfix_footer />
      </div>
    </Layouts.app>
    """
  end
end
