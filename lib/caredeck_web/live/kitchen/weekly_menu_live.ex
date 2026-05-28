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
      <div class="mx-auto max-w-4xl px-4 py-6">
        <h1 class="text-display-md text-ink-900 mb-2">Weekly menu</h1>
        <p class="text-ink-500 text-sm mb-4">
          Week of {Calendar.strftime(@week_start, "%d %b %Y")}
        </p>

        <div
          :if={!@has_active_template?}
          class="bg-card border border-divider rounded-card px-4 py-3 mb-4 text-ink-500 text-sm"
        >
          Set up a default week first by activating a menu template (no active template yet for this facility).
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-7 gap-3">
          <article
            :for={date <- @week}
            class={[
              "bg-card rounded-card shadow-card p-4",
              date == @today && "ring-2 ring-brand"
            ]}
          >
            <header class="flex items-center justify-between mb-3">
              <div>
                <p class="text-ink-500 text-xs uppercase tracking-wide">
                  {Calendar.strftime(date, "%a")}
                </p>
                <p class="text-ink-900 font-semibold">{Calendar.strftime(date, "%d %b")}</p>
              </div>
              <.link
                navigate={~p"/kitchen/weekly-menu/#{Date.to_iso8601(date)}"}
                class="text-brand text-xs hover:text-brand-strong"
              >
                Edit
              </.link>
            </header>

            <% menu = Map.get(@menus, date) %>

            <ul :if={menu} class="space-y-1 text-xs">
              <li :for={slot <- menu.slots}>
                <span class="text-ink-500">{MealCategory.label(slot.category)}:</span>
                <span class="text-ink-900">{slot.product.name}</span>
              </li>
            </ul>

            <button
              :if={!menu}
              type="button"
              phx-click="materialise"
              phx-value-date={Date.to_iso8601(date)}
              class="rounded-button bg-brand-soft text-brand text-xs px-3 py-1.5 hover:bg-brand hover:text-white"
            >
              Materialise
            </button>
          </article>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
