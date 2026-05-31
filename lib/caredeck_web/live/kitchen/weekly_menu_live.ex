defmodule CaredeckWeb.Kitchen.WeeklyMenuLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Kitchen
  alias Caredeck.Kitchen.{DayMenu, MealCategory, MenuTemplate}

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    facility = socket.assigns[:current_facility]
    today = Date.utc_today()
    week_start = Date.add(today, -(Date.day_of_week(today) - 1))
    week = Enum.map(0..6, &Date.add(week_start, &1))

    {:ok,
     socket
     |> assign(:page_title, "Weekly menu")
     |> assign(:week_start, week_start)
     |> assign(:today, today)
     |> assign(:week, week)
     |> assign(:has_active_template?, has_active_template?(facility))
     |> assign(:menus, load_week(facility, week))}
  end

  defp has_active_template?(nil), do: false

  defp has_active_template?(facility) do
    case Ash.read_one(
           MenuTemplate |> Ash.Query.filter(is_active == true),
           tenant: facility.id,
           authorize?: false
         ) do
      {:ok, %{}} -> true
      _ -> false
    end
  end

  defp load_week(nil, _week), do: %{}

  defp load_week(facility, week) do
    {min, max} = {hd(week), List.last(week)}

    DayMenu
    |> Ash.Query.filter(date >= ^min and date <= ^max)
    |> Ash.Query.load(slots: [:product])
    |> Ash.read!(tenant: facility.id, authorize?: false)
    |> Map.new(fn d -> {d.date, d} end)
  end

  @impl true
  def handle_event("materialise", %{"date" => date_str}, socket) do
    date = Date.from_iso8601!(date_str)
    facility = socket.assigns.current_facility
    Kitchen.Materialise.materialise_day(facility.id, date)
    {:noreply, assign(socket, :menus, load_week(facility, socket.assigns.week))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-7xl px-4 sm:px-6 py-6">
        <header class="flex items-end justify-between mb-6 gap-4">
          <div>
            <h1 class="text-display-md text-ink-900">Weekly menu</h1>
            <p class="text-ink-500 text-sm">
              Week of {Calendar.strftime(@week_start, "%d %b %Y")}
            </p>
          </div>
          <.link
            navigate={~p"/kitchen/summary"}
            class="text-brand text-sm hover:text-brand-strong"
          >
            Today's orders &rarr;
          </.link>
        </header>

        <div
          :if={!@has_active_template?}
          class="bg-card border border-divider rounded-card px-4 py-3 mb-4 text-ink-500 text-sm"
        >
          Set up a default week first by activating a menu template (no active template yet for this facility).
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          <article
            :for={date <- @week}
            class={[
              "bg-card rounded-card shadow-card p-5 flex flex-col gap-4",
              date == @today && "ring-2 ring-brand"
            ]}
          >
            <header class="flex items-start justify-between gap-3">
              <div>
                <p class="text-ink-500 text-xs uppercase tracking-wide">
                  {Calendar.strftime(date, "%A")}
                </p>
                <p class="text-ink-900 font-semibold text-lg">
                  {Calendar.strftime(date, "%d %b")}
                </p>
              </div>
              <.link
                navigate={~p"/kitchen/weekly-menu/#{Date.to_iso8601(date)}"}
                class="rounded-button border border-divider text-ink-500 text-xs font-medium px-3 py-1.5 hover:border-brand hover:text-ink-900 whitespace-nowrap"
              >
                Edit
              </.link>
            </header>

            <% menu = Map.get(@menus, date) %>
            <% slot_by_cat = (menu && Map.new(menu.slots, &{&1.category, &1})) || %{} %>

            <ul class="space-y-2 text-sm">
              <li
                :for={cat <- MealCategory.all()}
                class="flex items-baseline justify-between gap-3"
              >
                <span class="text-ink-500 text-xs uppercase tracking-wide shrink-0">
                  {MealCategory.label(cat)}
                </span>
                <span class="text-ink-900 text-right">
                  {(Map.get(slot_by_cat, cat) || %{}) |> Map.get(:product) |> product_name()}
                </span>
              </li>
            </ul>

            <button
              :if={!menu}
              type="button"
              phx-click="materialise"
              phx-value-date={Date.to_iso8601(date)}
              class="mt-auto rounded-button bg-brand text-white text-sm font-medium px-3 py-2 hover:bg-brand-strong"
            >
              Materialise this day
            </button>
          </article>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp product_name(nil), do: "—"
  defp product_name(%{name: name}), do: name
end
