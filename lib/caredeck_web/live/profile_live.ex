defmodule CaredeckWeb.ProfileLive do
  use CaredeckWeb, :live_view

  alias Caredeck.People.{CaregiverProfile, RelativeOfResident, Resident}

  require Ash.Query

  @impl true
  def mount(%{"resident_id" => id} = params, _session, socket) do
    facility = socket.assigns.current_facility
    user = socket.assigns[:current_user]
    tab = Map.get(params, "tab", "relatives")

    cond do
      is_nil(facility) ->
        {:ok, push_navigate(socket, to: ~p"/feed")}

      true ->
        actor = user || socket.assigns[:current_team]

        case Ash.get(Resident, id, tenant: facility.id, actor: actor) do
          {:ok, resident} ->
            relatives = load_relatives(facility, resident)
            caregivers = load_caregivers(facility)

            {:ok,
             socket
             |> assign(:resident, resident)
             |> assign(:relatives, relatives)
             |> assign(:caregivers, caregivers)
             |> assign(:tab, tab)
             |> assign(:page_title, "Profile · #{resident.first_name}")}

          _ ->
            {:ok, push_navigate(socket, to: ~p"/feed")}
        end
    end
  end

  defp load_relatives(facility, resident) do
    RelativeOfResident
    |> Ash.Query.filter(resident_id == ^resident.id)
    |> Ash.Query.load([:relative])
    |> Ash.read!(tenant: facility.id, authorize?: false)
    |> Enum.map(fn link -> %{relative: link.relative, relationship: link.relationship} end)
  end

  defp load_caregivers(facility) do
    CaregiverProfile
    |> Ash.read!(tenant: facility.id, authorize?: false)
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, tab)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-2xl px-4 py-6 pb-24">
        <div class="flex items-start justify-between mb-2 gap-3 flex-wrap">
          <h1 class="text-display-md text-ink-900">
            {@resident.first_name} {@resident.last_name}
          </h1>
          <div class="flex items-center gap-2 flex-wrap">
            <.link
              navigate={~p"/kitchen/order/#{@resident.id}"}
              class="rounded-button bg-brand text-white text-sm font-medium px-4 py-2 hover:bg-brand-strong whitespace-nowrap"
            >
              Order meal &rarr;
            </.link>
            <.link
              navigate={~p"/residents/#{@resident.id}/diet"}
              class="rounded-button bg-card border border-divider text-ink-900 text-sm font-medium px-4 py-2 hover:border-brand whitespace-nowrap"
            >
              Diet profile
            </.link>
          </div>
        </div>
        <p :if={@resident.birth_name} class="text-ink-500 text-sm mb-4">
          {@resident.birth_name}
        </p>

        <nav class="flex gap-4 border-b border-divider mb-4">
          <button
            type="button"
            phx-click="switch_tab"
            phx-value-tab="relatives"
            class={[
              "py-3 -mb-px border-b-2",
              if(@tab == "relatives",
                do: "border-brand text-brand",
                else: "border-transparent text-ink-500 hover:text-ink-900"
              )
            ]}
          >
            Relatives ({length(@relatives)})
          </button>
          <button
            type="button"
            phx-click="switch_tab"
            phx-value-tab="caregivers"
            class={[
              "py-3 -mb-px border-b-2",
              if(@tab == "caregivers",
                do: "border-brand text-brand",
                else: "border-transparent text-ink-500 hover:text-ink-900"
              )
            ]}
          >
            Caregivers ({length(@caregivers)})
          </button>
        </nav>

        <ul
          :if={@tab == "relatives"}
          class="divide-y divide-divider bg-card rounded-card shadow-card"
        >
          <li :if={@relatives == []} class="px-4 py-6 text-ink-500 text-sm text-center">
            No relatives yet.
          </li>
          <li :for={row <- @relatives} class="px-4 py-3 flex items-center gap-3">
            <.avatar url={row.relative.avatar_url} initials={initials(row.relative.display_name)} />
            <div class="flex-1">
              <p class="text-ink-900 font-medium">{row.relative.display_name}</p>
              <p class="text-ink-500 text-xs">{humanize_relationship(row.relationship)}</p>
            </div>
            <span
              :if={@current_user && row.relative.user_id == @current_user.id}
              class="text-brand text-xs font-medium"
            >
              Me
            </span>
          </li>
        </ul>

        <ul
          :if={@tab == "caregivers"}
          class="divide-y divide-divider bg-card rounded-card shadow-card"
        >
          <li :if={@caregivers == []} class="px-4 py-6 text-ink-500 text-sm text-center">
            No caregiver profiles yet.
          </li>
          <li :for={c <- @caregivers} class="px-4 py-3 flex items-center gap-3">
            <.avatar url={c.avatar_url} initials={initials(c.display_name)} />
            <div class="flex-1">
              <p class="text-ink-900 font-medium">{c.display_name}</p>
              <p class="text-ink-500 text-xs">{c.role_label || "Caregiver"}</p>
            </div>
          </li>
        </ul>
      </div>

      <.link
        :if={@current_user}
        navigate={~p"/residents/#{@resident.id}/invite"}
        class="fixed bottom-6 right-6 inline-flex h-14 w-14 items-center justify-center rounded-full bg-brand text-white text-display-sm shadow-card"
      >
        +
      </.link>
    </Layouts.app>
    """
  end

  attr :url, :string, default: nil
  attr :initials, :string, default: ""

  defp avatar(assigns) do
    ~H"""
    <div class="h-10 w-10 rounded-full bg-brand-soft text-brand text-sm font-semibold flex items-center justify-center overflow-hidden">
      <%= if @url do %>
        <img src={"/attachments/" <> @url} class="h-full w-full object-cover" alt="" />
      <% else %>
        {@initials}
      <% end %>
    </div>
    """
  end

  defp initials(nil), do: ""

  defp initials(name) do
    name
    |> String.split()
    |> Enum.map(&String.first/1)
    |> Enum.take(2)
    |> Enum.join()
    |> String.upcase()
  end

  defp humanize_relationship(nil), do: ""

  defp humanize_relationship(atom) do
    atom |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
  end
end
