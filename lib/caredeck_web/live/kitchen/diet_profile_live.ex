defmodule CaredeckWeb.Kitchen.DietProfileLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Kitchen.{MealCategory, ResidentDietProfile}
  alias Caredeck.People.Resident

  require Ash.Query

  @impl true
  def mount(%{"resident_id" => rid}, _session, socket) do
    facility = socket.assigns[:current_facility]
    actor = current_actor(socket)

    cond do
      is_nil(facility) ->
        {:ok, push_navigate(socket, to: ~p"/feed")}

      true ->
        case Ash.get(Resident, rid, tenant: facility.id, actor: actor) do
          {:ok, resident} ->
            profile = load_profile(facility, rid)

            {:ok,
             socket
             |> assign(:page_title, "Diet profile")
             |> assign(:resident, resident)
             |> assign(:profile, profile)
             |> assign(:allergens, csv((profile && profile.allergens) || []))
             |> assign(:preferences, joinl((profile && profile.preferences) || []))
             |> assign(:skip_categories, (profile && profile.skip_categories) || [])
             |> assign(:notes, (profile && profile.notes) || "")}

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

  defp csv(list), do: Enum.join(list, ", ")
  defp joinl(list), do: Enum.join(list, "\n")

  @impl true
  def handle_event("save", params, socket) do
    facility = socket.assigns.current_facility
    actor = current_actor(socket)

    attrs = %{
      facility_id: facility.id,
      resident_id: socket.assigns.resident.id,
      allergens: split_csv(params["allergens"]),
      preferences: split_lines(params["preferences"]),
      skip_categories: parse_skip(params["skip_categories"]),
      notes: params["notes"]
    }

    ResidentDietProfile
    |> Ash.Changeset.for_create(:create, attrs, tenant: facility.id, actor: actor)
    |> Ash.create!(tenant: facility.id, actor: actor)

    {:noreply,
     socket
     |> put_flash(:info, "Diet profile saved.")
     |> assign(:allergens, csv(attrs.allergens))
     |> assign(:preferences, joinl(attrs.preferences))
     |> assign(:skip_categories, attrs.skip_categories)
     |> assign(:notes, attrs.notes || "")}
  end

  defp split_csv(nil), do: []

  defp split_csv(s) do
    s
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp split_lines(nil), do: []

  defp split_lines(s) do
    s
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_skip(nil), do: []
  defp parse_skip(list) when is_list(list), do: Enum.map(list, &String.to_existing_atom/1)
  defp parse_skip(_), do: []

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-md px-4 py-6">
        <h1 class="text-display-sm text-ink-900 mb-4">
          Diet profile — {@resident.first_name}
        </h1>

        <form phx-submit="save" class="space-y-4">
          <label class="block">
            <span class="text-ink-900 text-sm font-medium">Allergens (comma-separated)</span>
            <input
              name="allergens"
              value={@allergens}
              class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
            />
          </label>

          <label class="block">
            <span class="text-ink-900 text-sm font-medium">Preferences (one per line)</span>
            <textarea
              name="preferences"
              rows="4"
              class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
            >{@preferences}</textarea>
          </label>

          <fieldset>
            <legend class="text-ink-900 text-sm font-medium mb-2">Skip categories</legend>
            <label :for={cat <- MealCategory.all()} class="flex items-center gap-2 mb-1">
              <input
                type="checkbox"
                name="skip_categories[]"
                value={cat}
                checked={cat in @skip_categories}
                class="rounded-input border-divider"
              /> <span class="text-ink-900 text-sm">{MealCategory.label(cat)}</span>
            </label>
          </fieldset>

          <label class="block">
            <span class="text-ink-900 text-sm font-medium">Notes</span>
            <textarea
              name="notes"
              rows="3"
              class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
            >{@notes}</textarea>
          </label>

          <button type="submit" class="w-full rounded-button bg-brand text-white px-4 py-2">
            Save
          </button>
        </form>
      </div>
    </Layouts.app>
    """
  end
end
