defmodule CaredeckWeb.Kitchen.DayEditorLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Kitchen
  alias Caredeck.Kitchen.{DayMenu, DayMenuSlot, MealCategory, Product}

  require Ash.Query

  @impl true
  def mount(%{"date" => date_str}, _session, socket) do
    date = Date.from_iso8601!(date_str)
    facility = socket.assigns.current_facility

    day_menu = ensure_day_menu(facility, date)

    {:ok,
     socket
     |> assign(:page_title, "Day editor")
     |> assign(:date, date)
     |> assign(:day_menu, day_menu)
     |> assign(:products, load_products(facility))
     |> assign(:slot_by_category, slots_by_category(day_menu))}
  end

  defp ensure_day_menu(facility, date) do
    case Ash.read_one(
           DayMenu
           |> Ash.Query.filter(date == ^date)
           |> Ash.Query.load(slots: [:product]),
           tenant: facility.id,
           authorize?: false
         ) do
      {:ok, %{} = m} -> m
      _ -> Kitchen.Materialise.materialise_day(facility.id, date)
    end
  end

  defp load_products(facility) do
    Product
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!(tenant: facility.id, authorize?: false)
    |> Enum.group_by(& &1.category)
  end

  defp slots_by_category(day_menu),
    do: Map.new(day_menu.slots, fn s -> {s.category, s} end)

  @impl true
  def handle_event("pick", %{"category" => cat, "product_id" => pid}, socket) do
    facility = socket.assigns.current_facility
    cat = String.to_existing_atom(cat)

    DayMenuSlot
    |> Ash.Changeset.for_create(
      :create,
      %{
        facility_id: facility.id,
        day_menu_id: socket.assigns.day_menu.id,
        category: cat,
        product_id: pid
      },
      tenant: facility.id,
      actor: socket.assigns.current_team
    )
    |> Ash.create!(tenant: facility.id, actor: socket.assigns.current_team)

    refreshed =
      Ash.load!(socket.assigns.day_menu, [slots: [:product]],
        tenant: facility.id,
        authorize?: false
      )

    {:noreply,
     socket
     |> assign(:day_menu, refreshed)
     |> assign(:slot_by_category, slots_by_category(refreshed))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-2xl px-4 py-6">
        <.link navigate={~p"/kitchen/weekly-menu"} class="text-ink-500 text-sm">
          &larr; Back to weekly menu
        </.link>

        <h1 class="text-display-md text-ink-900 mt-2 mb-4">
          {Calendar.strftime(@date, "%A %d %B %Y")}
        </h1>

        <section
          :for={cat <- MealCategory.all()}
          class="bg-card rounded-card shadow-card mb-3 p-4"
        >
          <h2 class="text-ink-900 font-medium mb-2">{MealCategory.label(cat)}</h2>

          <% current = Map.get(@slot_by_category, cat) %>
          <p :if={current} class="text-ink-500 text-sm mb-2">
            Currently: <span class="text-ink-900">{current.product.name}</span>
          </p>

          <% available = Map.get(@products, cat, []) %>
          <p :if={available == []} class="text-ink-500 text-sm">
            No products in this category yet.
          </p>

          <div :if={available != []} class="flex gap-2 flex-wrap">
            <button
              :for={p <- available}
              type="button"
              phx-click="pick"
              phx-value-category={cat}
              phx-value-product_id={p.id}
              class={[
                "px-3 py-1.5 rounded-input border text-sm",
                current && current.product_id == p.id && "bg-brand text-white border-brand",
                !(current && current.product_id == p.id) &&
                  "bg-card text-ink-900 border-divider hover:border-brand"
              ]}
            >
              {p.name}
            </button>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
