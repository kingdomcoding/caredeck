defmodule CaredeckWeb.Layouts do
  use CaredeckWeb, :html

  require Ash.Query

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :current_user, :map, default: nil
  attr :current_team, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    profile_rid = profile_resident_id(assigns[:current_user])
    unread = unread_count(assigns[:current_user])

    assigns =
      assigns
      |> assign(:profile_rid, profile_rid)
      |> assign(:unread, unread)

    ~H"""
    <header class="border-b border-divider bg-card">
      <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
        <a href="/" class="flex items-center">
          <img src={~p"/images/brand/caredeck-lockup.svg"} alt="Caredeck" height="32" class="h-8" />
        </a>
        <nav class="flex items-center gap-6 text-sm text-ink-500">
          <.link
            :if={@current_user && @profile_rid}
            navigate={~p"/residents/#{@profile_rid}"}
            class="hover:text-ink-900"
          >
            Profile
          </.link>
          <.link :if={@current_user} navigate={~p"/profile/edit"} class="hover:text-ink-900">
            Edit
          </.link>
          <.link
            :if={@current_user}
            navigate={~p"/notifications"}
            class="relative hover:text-ink-900"
            aria-label="Notifications"
          >
            <span aria-hidden="true">🔔</span>
            <span
              :if={@unread > 0}
              class="absolute -top-1 -right-2 min-w-[18px] h-[18px] px-1 rounded-full bg-like-red text-white text-[10px] font-bold flex items-center justify-center"
            >
              {format_count(@unread)}
            </span>
          </.link>
          <span :if={@current_user} class="text-ink-900">{@current_user.email}</span>
          <.link
            :if={@current_user}
            href={~p"/sign-out"}
            method="delete"
            class="hover:text-ink-900"
          >
            Sign out
          </.link>
          <span :if={@current_team} class="text-ink-900">{@current_team.name}</span>
          <.link :if={@current_team} href={~p"/team/sign-out"} class="hover:text-ink-900">
            Sign out
          </.link>
        </nav>
      </div>
    </header>

    <main class="bg-page min-h-[calc(100vh-65px)]">
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end

  defp unread_count(nil), do: 0

  defp unread_count(user) do
    case Ash.read(
           Caredeck.Org.FacilityMembership
           |> Ash.Query.filter(user_id == ^user.id),
           authorize?: false
         ) do
      {:ok, [_ | _] = memberships} ->
        Enum.reduce(memberships, 0, fn m, acc ->
          n =
            Caredeck.Notifications.Notification
            |> Ash.Query.filter(user_id == ^user.id and is_nil(read_at))
            |> Ash.read!(tenant: m.facility_id, authorize?: false)
            |> length()

          acc + n
        end)

      _ ->
        0
    end
  end

  defp format_count(n) when n > 99, do: "99+"
  defp format_count(n), do: to_string(n)

  defp profile_resident_id(nil), do: nil

  defp profile_resident_id(user) do
    case Ash.read(
           Caredeck.Org.FacilityMembership
           |> Ash.Query.filter(user_id == ^user.id),
           authorize?: false
         ) do
      {:ok, memberships} ->
        Enum.find_value(memberships, nil, fn membership ->
          first_relative_link(user.id, membership.facility_id)
        end)

      _ ->
        nil
    end
  end

  defp first_relative_link(user_id, facility_id) do
    case Ash.read(
           Caredeck.People.Relative
           |> Ash.Query.filter(user_id == ^user_id),
           tenant: facility_id,
           authorize?: false
         ) do
      {:ok, [_ | _] = relatives} ->
        relative_ids = Enum.map(relatives, & &1.id)

        case Ash.read(
               Caredeck.People.RelativeOfResident
               |> Ash.Query.filter(relative_id in ^relative_ids)
               |> Ash.Query.sort(inserted_at: :asc)
               |> Ash.Query.limit(1),
               tenant: facility_id,
               authorize?: false
             ) do
          {:ok, [%{resident_id: rid} | _]} -> rid
          _ -> nil
        end

      _ ->
        nil
    end
  end
end
