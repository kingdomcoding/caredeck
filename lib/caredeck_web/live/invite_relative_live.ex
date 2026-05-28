defmodule CaredeckWeb.InviteRelativeLive do
  use CaredeckWeb, :live_view

  alias Caredeck.People.{Relative, RelativeInvitation, RelativeOfResident, Resident}

  require Ash.Query

  @impl true
  def mount(%{"resident_id" => id}, _session, socket) do
    facility = socket.assigns.current_facility
    user = socket.assigns[:current_user]

    cond do
      is_nil(facility) or is_nil(user) ->
        {:ok, push_navigate(socket, to: ~p"/feed")}

      true ->
        case Ash.get(Resident, id, tenant: facility.id, actor: user) do
          {:ok, resident} ->
            if inviter_in_graph?(facility, user, resident) do
              {:ok,
               socket
               |> assign(:resident, resident)
               |> assign(:email, "")
               |> assign(:relationship, "")
               |> assign(:error, nil)
               |> assign(:page_title, "Invite a relative")}
            else
              {:ok,
               socket
               |> put_flash(:error, "You can only invite relatives for residents you're connected to.")
               |> push_navigate(to: ~p"/feed")}
            end

          _ ->
            {:ok, push_navigate(socket, to: ~p"/feed")}
        end
    end
  end

  defp inviter_in_graph?(facility, user, resident) do
    relatives =
      Relative
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.read!(tenant: facility.id, authorize?: false)

    relative_ids = Enum.map(relatives, & &1.id)

    if relative_ids == [] do
      false
    else
      RelativeOfResident
      |> Ash.Query.filter(relative_id in ^relative_ids and resident_id == ^resident.id)
      |> Ash.read!(tenant: facility.id, authorize?: false)
      |> Kernel.!=([])
    end
  end

  @impl true
  def handle_event("send", params, socket) do
    email = params |> Map.get("email", "") |> String.trim()
    rel = Map.get(params, "relationship", "")
    facility = socket.assigns.current_facility
    user = socket.assigns.current_user
    resident = socket.assigns.resident

    relationship =
      case rel do
        "" -> nil
        s -> String.to_existing_atom(s)
      end

    result =
      RelativeInvitation
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          inviter_user_id: user.id,
          resident_id: resident.id,
          email: email,
          suggested_relationship: relationship
        },
        tenant: facility.id,
        actor: user
      )
      |> Ash.create()

    case result do
      {:ok, _invitation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent to #{email}.")
         |> push_navigate(to: ~p"/residents/#{resident.id}")}

      {:error, %{errors: errors}} ->
        message =
          case errors do
            [%{message: m} | _] -> m
            _ -> "Could not send invitation."
          end

        {:noreply, assign(socket, :error, message)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_team={@current_team}
    >
      <div class="mx-auto max-w-md px-4 py-6">
        <h1 class="text-display-md text-ink-900 mb-2">Invite a relative</h1>
        <p class="text-ink-500 mb-4">
          Inviting for {@resident.first_name} {@resident.last_name}
        </p>

        <form phx-submit="send" class="space-y-4">
          <label class="block">
            <span class="text-ink-900 text-sm font-medium">Email</span>
            <input
              type="email"
              name="email"
              required
              value={@email}
              class="mt-1 block w-full rounded-input border border-divider px-3 py-2 text-ink-900 focus:outline-none focus:ring-2 focus:ring-brand"
            />
          </label>

          <label class="block">
            <span class="text-ink-900 text-sm font-medium">Relationship (suggested)</span>
            <select
              name="relationship"
              class="mt-1 block w-full rounded-input border border-divider px-3 py-2 text-ink-900 bg-card"
            >
              <option value="">— choose —</option>
              <%= for {value, label} <- relationship_options() do %>
                <option value={value} selected={@relationship == value}>{label}</option>
              <% end %>
            </select>
          </label>

          <p :if={@error} class="text-red-600 text-sm">{@error}</p>

          <div class="flex justify-between items-center">
            <.link
              navigate={~p"/feed"}
              class="text-ink-500 text-sm hover:text-ink-900"
            >
              Cancel
            </.link>
            <button type="submit" class="rounded-button bg-brand text-white px-4 py-2 text-sm">
              Send invitation
            </button>
          </div>
        </form>
      </div>
    </Layouts.app>
    """
  end

  defp relationship_options do
    [
      {"daughter", "Daughter"},
      {"son", "Son"},
      {"niece", "Niece"},
      {"nephew", "Nephew"},
      {"granddaughter", "Granddaughter"},
      {"grandson", "Grandson"},
      {"wife", "Wife"},
      {"husband", "Husband"},
      {"spouse", "Spouse"},
      {"partner", "Partner"},
      {"sibling", "Sibling"},
      {"legal_guardian", "Legal guardian"},
      {"other", "Other"}
    ]
  end
end
