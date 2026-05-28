defmodule CaredeckWeb.Kitchen.SummaryLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Kitchen.{MealCategory, ResidentMealOrder}
  alias CaredeckWeb.Endpoint

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    facility = socket.assigns[:current_facility]

    if connected?(socket) and facility do
      Endpoint.subscribe("facility:#{facility.id}:kitchen")
    end

    today = Date.utc_today()

    {:ok,
     socket
     |> assign(:page_title, "Today's orders")
     |> assign(:today, today)
     |> assign(:aggregated, aggregate(facility, today))}
  end

  defp aggregate(nil, _date), do: %{}

  defp aggregate(facility, date) do
    ResidentMealOrder
    |> Ash.Query.filter(date == ^date and state == :ordered)
    |> Ash.Query.load(:product)
    |> Ash.read!(tenant: facility.id, authorize?: false)
    |> Enum.group_by(& &1.category)
    |> Map.new(fn {cat, orders} ->
      counts =
        orders
        |> Enum.frequencies_by(& &1.product.name)
        |> Enum.sort_by(fn {_, n} -> -n end)

      {cat, counts}
    end)
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "order_changed"}, socket) do
    {:noreply,
     assign(
       socket,
       :aggregated,
       aggregate(socket.assigns.current_facility, socket.assigns.today)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-2xl px-4 py-6">
        <header class="mb-4">
          <h1 class="text-display-md text-ink-900">Today's orders</h1>
          <p class="text-ink-500 text-sm">{Calendar.strftime(@today, "%A %d %B %Y")}</p>
        </header>

        <section
          :for={cat <- MealCategory.all()}
          class="bg-card rounded-card shadow-card p-4 mb-3"
        >
          <h2 class="text-ink-900 font-medium mb-3">{MealCategory.label(cat)}</h2>

          <% counts = Map.get(@aggregated, cat, []) %>

          <p :if={counts == []} class="text-ink-500 text-sm">No orders yet.</p>

          <ul :if={counts != []} class="space-y-2">
            <li :for={{name, n} <- counts} class="flex items-center justify-between">
              <span class="text-ink-900">{name}</span>
              <span class="text-brand font-semibold">×{n}</span>
            </li>
          </ul>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
