defmodule CaredeckWeb.Kitchen.ResidentOrderLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Kitchen
  alias Caredeck.Kitchen.{DayMenu, MealCategory, ResidentDietProfile, ResidentMealOrder}
  alias Caredeck.People.Resident

  require Ash.Query

  @impl true
  def mount(%{"resident_id" => rid} = params, _session, socket) do
    facility = socket.assigns[:current_facility]
    actor = current_actor(socket)
    date = parse_date(params["date"])

    cond do
      is_nil(facility) ->
        {:ok, push_navigate(socket, to: ~p"/feed")}

      true ->
        case Ash.get(Resident, rid, tenant: facility.id, actor: actor) do
          {:ok, resident} ->
            day_menu = ensure_day_menu(facility, date)
            profile = load_profile(facility, rid)
            orders = load_orders(facility, rid, date)

            {:ok,
             socket
             |> assign(:page_title, "Order for #{resident.first_name}")
             |> assign(:resident, resident)
             |> assign(:date, date)
             |> assign(:day_menu, day_menu)
             |> assign(:profile, profile)
             |> assign(:orders_by_cat, Map.new(orders, &{&1.category, &1}))}

          _ ->
            {:ok,
             socket
             |> put_flash(:error, "Resident not found.")
             |> push_navigate(to: ~p"/feed")}
        end
    end
  end

  defp current_actor(socket) do
    socket.assigns[:current_team] || socket.assigns[:current_user]
  end

  defp parse_date(nil), do: Date.utc_today()
  defp parse_date(str), do: Date.from_iso8601!(str)

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

  defp load_profile(facility, rid) do
    case Ash.read_one(
           ResidentDietProfile |> Ash.Query.filter(resident_id == ^rid),
           tenant: facility.id,
           authorize?: false
         ) do
      {:ok, %{} = p} -> p
      _ -> nil
    end
  end

  defp load_orders(facility, rid, date) do
    ResidentMealOrder
    |> Ash.Query.filter(resident_id == ^rid and date == ^date)
    |> Ash.read!(tenant: facility.id, authorize?: false)
  end

  @impl true
  def handle_event("order", %{"category" => cat, "product_id" => "skip"}, socket) do
    facility = socket.assigns.current_facility
    actor = current_actor(socket)
    cat = String.to_existing_atom(cat)
    planned = Enum.find(socket.assigns.day_menu.slots, &(&1.category == cat))

    cond do
      is_nil(planned) ->
        {:noreply, socket}

      true ->
        attrs = %{
          facility_id: facility.id,
          resident_id: socket.assigns.resident.id,
          date: socket.assigns.date,
          category: cat,
          product_id: planned.product_id,
          state: :cancelled,
          ordered_by_user_id: socket.assigns[:current_user] && socket.assigns.current_user.id,
          ordered_by_team_id: socket.assigns[:current_team] && socket.assigns.current_team.id
        }

        case ResidentMealOrder
             |> Ash.Changeset.for_create(:create, attrs, tenant: facility.id, actor: actor)
             |> Ash.create(tenant: facility.id, actor: actor) do
          {:ok, _} ->
            orders = load_orders(facility, socket.assigns.resident.id, socket.assigns.date)
            {:noreply, assign(socket, :orders_by_cat, Map.new(orders, &{&1.category, &1}))}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "You can't update orders for this resident.")}
        end
    end
  end

  def handle_event("order", %{"category" => cat, "product_id" => pid}, socket) do
    facility = socket.assigns.current_facility
    actor = current_actor(socket)
    cat = String.to_existing_atom(cat)

    attrs = %{
      facility_id: facility.id,
      resident_id: socket.assigns.resident.id,
      date: socket.assigns.date,
      category: cat,
      product_id: pid,
      state: :ordered,
      ordered_by_user_id: socket.assigns[:current_user] && socket.assigns.current_user.id,
      ordered_by_team_id: socket.assigns[:current_team] && socket.assigns.current_team.id
    }

    case ResidentMealOrder
         |> Ash.Changeset.for_create(:create, attrs, tenant: facility.id, actor: actor)
         |> Ash.create(tenant: facility.id, actor: actor) do
      {:ok, _} ->
        orders = load_orders(facility, socket.assigns.resident.id, socket.assigns.date)
        {:noreply, assign(socket, :orders_by_cat, Map.new(orders, &{&1.category, &1}))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "You can't order for this resident.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-md px-4 py-6">
        <header class="mb-4">
          <h1 class="text-display-sm text-ink-900">
            Meals for {@resident.first_name} {@resident.last_name}
          </h1>
          <p class="text-ink-500 text-sm">{Calendar.strftime(@date, "%A %d %B %Y")}</p>
        </header>

        <p
          :if={@profile && @profile.allergens != []}
          class="text-like-red text-xs mb-3 bg-red-50 border border-red-200 rounded-input px-3 py-2"
        >
          Allergens: {Enum.join(@profile.allergens, ", ")}
        </p>

        <section
          :for={cat <- MealCategory.all()}
          class="bg-card rounded-card shadow-card p-4 mb-3"
        >
          <% planned = Enum.find(@day_menu.slots, &(&1.category == cat)) %>
          <% picked = Map.get(@orders_by_cat, cat) %>
          <% taken = picked && picked.state == :ordered %>
          <% skipped = picked && picked.state == :cancelled %>

          <header class="flex items-center justify-between mb-2 gap-2">
            <h2 class="text-ink-900 font-medium">{MealCategory.label(cat)}</h2>
            <span
              :if={taken}
              class="text-brand text-xs font-medium bg-brand-soft rounded-full px-2 py-0.5"
            >
              ✓ Ordered
            </span>
            <span
              :if={skipped}
              class="text-ink-500 text-xs font-medium bg-page border border-divider rounded-full px-2 py-0.5"
            >
              Skipped
            </span>
          </header>

          <p :if={planned} class="text-ink-500 text-xs mb-3">
            Today's plan: <span class="text-ink-900">{planned.product.name}</span>
          </p>
          <p :if={!planned} class="text-ink-300 text-xs mb-3">No plan for this category.</p>

          <div class="flex gap-2 flex-wrap">
            <button
              :if={planned}
              type="button"
              phx-click="order"
              phx-value-category={cat}
              phx-value-product_id={planned.product_id}
              class={[
                "px-3 py-1.5 rounded-input border text-sm font-medium",
                taken && "bg-brand text-white border-brand",
                !taken && "bg-card text-ink-900 border-divider hover:border-brand"
              ]}
            >
              Take the plan
            </button>
            <button
              :if={planned}
              type="button"
              phx-click="order"
              phx-value-category={cat}
              phx-value-product_id="skip"
              class={[
                "px-3 py-1.5 rounded-input border text-sm font-medium",
                skipped && "bg-ink-900 text-white border-ink-900",
                !skipped && "bg-card text-ink-500 border-divider hover:border-brand"
              ]}
            >
              Skip
            </button>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
