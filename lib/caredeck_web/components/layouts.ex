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
      <div class="mx-auto flex max-w-6xl items-center justify-between px-4 sm:px-6 py-4">
        <a href="/" class="flex items-center">
          <img src={~p"/images/brand/caredeck-lockup.svg"} alt="Caredeck" height="32" class="h-8" />
        </a>
        <nav class="flex items-center gap-3 sm:gap-6 text-sm text-ink-500">
          <.link
            :if={@current_user && @profile_rid}
            navigate={~p"/residents/#{@profile_rid}"}
            class="hidden md:inline-block hover:text-ink-900"
          >
            Profile
          </.link>
          <.link
            :if={@current_user}
            navigate={~p"/profile/edit"}
            class="hidden md:inline-block hover:text-ink-900"
          >
            Edit
          </.link>
          <.link
            :if={@current_user}
            navigate={~p"/notifications"}
            class="relative hidden md:inline-block hover:text-ink-900"
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
          <span :if={@current_user} class="hidden lg:inline-block text-ink-900 truncate max-w-[18ch]">
            {@current_user.email}
          </span>
          <.link
            :if={@current_user}
            href={~p"/sign-out"}
            method="delete"
            class="hidden md:inline-block hover:text-ink-900"
          >
            Sign out
          </.link>
          <.link
            :if={@current_team}
            navigate={~p"/feed"}
            class="hidden md:inline-block hover:text-ink-900"
          >
            Feed
          </.link>
          <.link
            :if={@current_team}
            navigate={~p"/residents"}
            class="hidden md:inline-block hover:text-ink-900"
          >
            Residents
          </.link>
          <.link
            :if={@current_team}
            navigate={~p"/kitchen/weekly-menu"}
            class="hidden md:inline-block hover:text-ink-900"
          >
            Kitchen
          </.link>
          <.link
            :if={@current_team}
            navigate={~p"/kitchen/summary"}
            class="hidden md:inline-block hover:text-ink-900"
          >
            Today's orders
          </.link>
          <span :if={@current_team} class="text-ink-900 truncate max-w-[14ch]">
            {@current_team.name}
          </span>
          <.link
            :if={@current_team}
            href={~p"/team/sign-out"}
            class="hidden md:inline-block hover:text-ink-900"
          >
            Sign out
          </.link>
        </nav>
      </div>
    </header>

    <main class="bg-page min-h-[calc(100vh-65px)] pb-16 md:pb-0">
      {render_slot(@inner_block)}
    </main>

    <nav
      :if={@current_user || @current_team}
      class="fixed bottom-0 inset-x-0 z-30 md:hidden border-t border-divider bg-card pb-[env(safe-area-inset-bottom)]"
      aria-label="Primary"
    >
      <ul class="grid grid-cols-4">
        <.nav_tab navigate={~p"/feed"} label="Home" icon={:home} />
        <.nav_tab
          :if={@current_team}
          navigate={~p"/kitchen/weekly-menu"}
          label="Kitchen"
          icon={:plate}
        />
        <.nav_tab
          :if={!@current_team and @profile_rid}
          navigate={~p"/residents/#{@profile_rid}"}
          label="Profile"
          icon={:user}
        />
        <.nav_tab
          :if={!@current_team and !@profile_rid}
          navigate={~p"/profile/edit"}
          label="Profile"
          icon={:user}
        />
        <.nav_tab
          :if={@current_team}
          navigate={~p"/residents"}
          label="Residents"
          icon={:user}
        />
        <.nav_tab
          :if={!@current_team}
          navigate={~p"/notifications"}
          label="Inbox"
          icon={:bell}
          badge={@unread}
        />
        <.nav_tab
          :if={!@current_team}
          href={~p"/sign-out"}
          method={:delete}
          label="Sign out"
          icon={:logout}
        />
        <.nav_tab
          :if={@current_team}
          href={~p"/team/sign-out"}
          label="Sign out"
          icon={:logout}
        />
      </ul>
    </nav>

    <.flash_group flash={@flash} />
    """
  end

  attr :navigate, :string, default: nil
  attr :href, :string, default: nil
  attr :method, :atom, default: nil
  attr :label, :string, required: true
  attr :icon, :atom, required: true
  attr :badge, :integer, default: 0

  defp nav_tab(assigns) do
    ~H"""
    <li>
      <.link
        navigate={@navigate}
        href={@href}
        method={@method}
        class="relative flex flex-col items-center py-2 text-xs text-ink-500 hover:text-ink-900"
      >
        <.nav_icon name={@icon} />
        <span class="mt-0.5">{@label}</span>
        <span
          :if={@badge > 0}
          class="absolute top-1 right-1/2 translate-x-4 min-w-[16px] h-[16px] px-1 rounded-full bg-like-red text-white text-[9px] font-bold flex items-center justify-center"
        >
          {format_count(@badge)}
        </span>
      </.link>
    </li>
    """
  end

  attr :name, :atom, required: true

  defp nav_icon(%{name: :home} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      class="h-6 w-6"
      aria-hidden="true"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M3 11l9-7 9 7v9a2 2 0 0 1-2 2h-4v-6h-6v6H5a2 2 0 0 1-2-2z"
      />
    </svg>
    """
  end

  defp nav_icon(%{name: :user} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      class="h-6 w-6"
      aria-hidden="true"
    >
      <circle cx="12" cy="8" r="4" />
      <path stroke-linecap="round" d="M4 21a8 8 0 0 1 16 0" />
    </svg>
    """
  end

  defp nav_icon(%{name: :bell} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      class="h-6 w-6"
      aria-hidden="true"
    >
      <path stroke-linecap="round" stroke-linejoin="round" d="M6 8a6 6 0 0 1 12 0v5l2 2H4l2-2z" />
      <path stroke-linecap="round" d="M10 19a2 2 0 0 0 4 0" />
    </svg>
    """
  end

  defp nav_icon(%{name: :plate} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      class="h-6 w-6"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="9" />
      <circle cx="12" cy="12" r="5" />
    </svg>
    """
  end

  defp nav_icon(%{name: :logout} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      class="h-6 w-6"
      aria-hidden="true"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M15 17l5-5-5-5M20 12H9M12 4H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h7"
      />
    </svg>
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
