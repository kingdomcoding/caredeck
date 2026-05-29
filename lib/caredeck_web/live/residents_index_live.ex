defmodule CaredeckWeb.ResidentsIndexLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Kitchen.ResidentDietProfile
  alias Caredeck.Org.Ward
  alias Caredeck.People.{Relative, RelativeOfResident, Resident}

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    facility = socket.assigns[:current_facility]
    actor = current_actor(socket)
    allowed_ids = allowed_resident_ids(facility, socket.assigns[:current_user])
    wards = load_wards(facility)

    {:ok,
     socket
     |> assign(:page_title, "Residents")
     |> assign(:facility, facility)
     |> assign(:actor, actor)
     |> assign(:wards, wards)
     |> assign(:query, "")
     |> assign(:ward_filter, "all")
     |> assign(:only_allergens, false)
     |> assign(:allowed_ids, allowed_ids)
     |> assign(:residents, load_residents(facility, allowed_ids, "", "all", false))}
  end

  defp current_actor(socket) do
    socket.assigns[:current_team] || socket.assigns[:current_user]
  end

  defp allowed_resident_ids(_facility, nil), do: :all

  defp allowed_resident_ids(facility, user) do
    relatives =
      Relative
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.read!(tenant: facility.id, authorize?: false)

    case relatives do
      [] ->
        []

      list ->
        relative_ids = Enum.map(list, & &1.id)

        RelativeOfResident
        |> Ash.Query.filter(relative_id in ^relative_ids)
        |> Ash.read!(tenant: facility.id, authorize?: false)
        |> Enum.map(& &1.resident_id)
        |> Enum.uniq()
    end
  end

  defp load_wards(nil), do: []

  defp load_wards(facility) do
    Ward
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!(tenant: facility.id, authorize?: false)
  end

  defp load_residents(nil, _allowed_ids, _query, _ward_filter, _only_allergens), do: []

  defp load_residents(facility, allowed_ids, query, ward_filter, only_allergens) do
    base =
      Resident
      |> Ash.Query.filter(lifecycle_state == :admitted)
      |> Ash.Query.sort(last_name: :asc, first_name: :asc)
      |> Ash.Query.load([:ward, relative_links: [:relative]])

    base =
      case allowed_ids do
        :all -> base
        [] -> Ash.Query.filter(base, id == ^"00000000-0000-0000-0000-000000000000")
        ids -> Ash.Query.filter(base, id in ^ids)
      end

    base =
      case ward_filter do
        "all" -> base
        "none" -> Ash.Query.filter(base, is_nil(ward_id))
        ward_id -> Ash.Query.filter(base, ward_id == ^ward_id)
      end

    base =
      case String.trim(query) do
        "" ->
          base

        q ->
          term = "%#{q}%"

          Ash.Query.filter(
            base,
            ilike(first_name, ^term) or ilike(last_name, ^term) or ilike(birth_name, ^term)
          )
      end

    residents = Ash.read!(base, tenant: facility.id, authorize?: false)

    allergen_set = load_allergen_set(facility, residents)

    residents
    |> Enum.map(&Map.put(&1, :has_allergens?, MapSet.member?(allergen_set, &1.id)))
    |> then(fn list ->
      if only_allergens, do: Enum.filter(list, & &1.has_allergens?), else: list
    end)
  end

  defp load_allergen_set(_facility, []), do: MapSet.new()

  defp load_allergen_set(facility, residents) do
    ids = Enum.map(residents, & &1.id)

    ResidentDietProfile
    |> Ash.Query.filter(resident_id in ^ids and not (allergens == []))
    |> Ash.read!(tenant: facility.id, authorize?: false)
    |> Enum.map(& &1.resident_id)
    |> MapSet.new()
  end

  @impl true
  def handle_event("search", %{"query" => q}, socket) do
    {:noreply,
     socket
     |> assign(:query, q)
     |> assign(
       :residents,
       load_residents(
         socket.assigns.facility,
         socket.assigns.allowed_ids,
         q,
         socket.assigns.ward_filter,
         socket.assigns.only_allergens
       )
     )}
  end

  def handle_event("filter", %{"ward" => ward, "only_allergens" => oa}, socket) do
    only_allergens = oa == "true"

    {:noreply,
     socket
     |> assign(:ward_filter, ward)
     |> assign(:only_allergens, only_allergens)
     |> assign(
       :residents,
       load_residents(
         socket.assigns.facility,
         socket.assigns.allowed_ids,
         socket.assigns.query,
         ward,
         only_allergens
       )
     )}
  end

  defp relationship_summary(resident) do
    relationships =
      resident.relative_links
      |> Enum.map(&humanize_relationship(&1.relationship))
      |> Enum.uniq()
      |> Enum.take(4)

    summary =
      case relationships do
        [] -> "No relatives linked"
        list -> Enum.join(list, ", ")
      end

    count = length(resident.relative_links)
    suffix = if count == 1, do: "relative", else: "relatives"
    "#{summary} · #{count} #{suffix}"
  end

  defp humanize_relationship(:legal_guardian), do: "legal guardian"
  defp humanize_relationship(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp humanize_relationship(_), do: ""

  defp initials(name) do
    name
    |> String.split()
    |> Enum.map(&String.first/1)
    |> Enum.take(2)
    |> Enum.join()
    |> String.upcase()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-5xl px-4 sm:px-6 py-6">
        <header class="mb-6">
          <h1 class="text-display-md text-ink-900">Residents</h1>
          <p class="text-ink-500 text-sm">
            {length(@residents)} {if length(@residents) == 1, do: "resident", else: "residents"}
          </p>
        </header>

        <div class="grid gap-3 mb-6 sm:grid-cols-[1fr_auto_auto] sm:items-center">
          <form phx-change="search" phx-submit="search">
            <input
              type="search"
              name="query"
              value={@query}
              placeholder="Search by name…"
              phx-debounce="200"
              class="w-full rounded-input border border-divider px-3 py-2 text-ink-900 focus:outline-none focus:ring-2 focus:ring-brand"
            />
          </form>

          <form phx-change="filter" class="flex items-center gap-3">
            <label class="text-ink-500 text-sm flex items-center gap-2">
              Ward
              <select
                name="ward"
                class="rounded-input border border-divider bg-card px-3 py-2 text-ink-900"
              >
                <option value="all" selected={@ward_filter == "all"}>All wards</option>
                <option value="none" selected={@ward_filter == "none"}>Unassigned</option>
                <option :for={w <- @wards} value={w.id} selected={@ward_filter == w.id}>
                  {w.name}
                </option>
              </select>
            </label>

            <label class="text-ink-500 text-sm flex items-center gap-2 whitespace-nowrap">
              <input
                type="checkbox"
                name="only_allergens"
                value="true"
                checked={@only_allergens}
                class="rounded-input border-divider"
              /> With allergens
            </label>
          </form>
        </div>

        <p :if={@residents == []} class="text-ink-500 text-sm text-center py-12">
          No residents match those filters.
        </p>

        <ul
          :if={@residents != []}
          class="bg-card rounded-card shadow-card divide-y divide-divider overflow-hidden"
        >
          <li
            :for={r <- @residents}
            class="px-4 sm:px-5 py-4 flex items-center gap-4 hover:bg-page transition"
          >
            <.link navigate={~p"/residents/#{r.id}"} class="flex items-center gap-4 flex-1 min-w-0">
              <div class="h-12 w-12 rounded-full bg-brand-soft text-brand text-sm font-semibold flex items-center justify-center overflow-hidden shrink-0">
                <%= if r.avatar_url do %>
                  <img src={"/attachments/" <> r.avatar_url} class="h-full w-full object-cover" alt="" />
                <% else %>
                  {initials("#{r.first_name} #{r.last_name}")}
                <% end %>
              </div>

              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 flex-wrap">
                  <p class="text-ink-900 font-medium">{r.first_name} {r.last_name}</p>
                  <span
                    :if={r.ward}
                    class="text-ink-500 text-xs uppercase tracking-wide bg-page rounded-full px-2 py-0.5"
                  >
                    {r.ward.name}
                  </span>
                  <span
                    :if={r.has_allergens?}
                    class="text-like-red text-xs font-medium bg-red-50 border border-red-200 rounded-full px-2 py-0.5"
                  >
                    ⚠ Allergens
                  </span>
                </div>
                <p class="text-ink-500 text-xs mt-0.5 truncate">
                  {relationship_summary(r)}
                </p>
              </div>
            </.link>

            <div class="flex items-center gap-2 shrink-0">
              <.link
                navigate={~p"/kitchen/order/#{r.id}"}
                class="rounded-button bg-brand text-white text-xs font-medium px-3 py-2 hover:bg-brand-strong whitespace-nowrap"
              >
                Order meal &rarr;
              </.link>
              <.link
                navigate={~p"/residents/#{r.id}/diet"}
                class="rounded-button bg-card border border-divider text-ink-900 text-xs font-medium px-3 py-2 hover:border-brand whitespace-nowrap hidden sm:inline-block"
              >
                Diet profile
              </.link>
            </div>
          </li>
        </ul>
      </div>
    </Layouts.app>
    """
  end
end
