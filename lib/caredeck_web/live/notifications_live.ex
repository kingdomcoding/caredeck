defmodule CaredeckWeb.NotificationsLive do
  use CaredeckWeb, :live_view

  alias Caredeck.{Accounts, People}
  alias Caredeck.Notifications.{Notification, Phrasebook}
  alias CaredeckWeb.Endpoint

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user]
    facility = socket.assigns[:current_facility]

    if connected?(socket) and user do
      Endpoint.subscribe("user:#{user.id}:notifications")
    end

    {:ok,
     socket
     |> assign(:page_title, "Notifications")
     |> assign(:notifications, load_notifications(facility, user))
     |> assign(:lookup, build_lookup(facility, user))}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: event}, socket)
      when event in ["notification_created", "notification_updated", "notification_deleted"] do
    facility = socket.assigns[:current_facility]
    user = socket.assigns[:current_user]

    {:noreply,
     socket
     |> assign(:notifications, load_notifications(facility, user))
     |> assign(:lookup, build_lookup(facility, user))}
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    facility = socket.assigns[:current_facility]
    user = socket.assigns[:current_user]

    Enum.each(socket.assigns.notifications, fn n ->
      if is_nil(n.read_at) do
        n
        |> Ash.Changeset.for_update(:mark_read, %{}, tenant: facility.id, actor: user)
        |> Ash.update!(tenant: facility.id, actor: user)
      end
    end)

    {:noreply, assign(socket, :notifications, load_notifications(facility, user))}
  end

  def handle_event("open", %{"id" => id}, socket) do
    facility = socket.assigns[:current_facility]
    user = socket.assigns[:current_user]

    target_path =
      case Ash.get(Notification, id, tenant: facility.id, actor: user) do
        {:ok, %{read_at: nil} = n} ->
          n
          |> Ash.Changeset.for_update(:mark_read, %{}, tenant: facility.id, actor: user)
          |> Ash.update!(tenant: facility.id, actor: user)

          target_path(n)

        {:ok, n} ->
          target_path(n)

        _ ->
          ~p"/notifications"
      end

    {:noreply, push_navigate(socket, to: target_path)}
  end

  defp target_path(%{target_kind: :post, target_id: pid}), do: ~p"/feed/#{pid}"
  defp target_path(%{target_kind: :resident, target_id: rid}), do: ~p"/residents/#{rid}"

  defp target_path(%{target_kind: :service_request, target_id: rid}),
    do: ~p"/services/requests/#{rid}"

  defp target_path(%{target_kind: :service_message, target_id: mid, facility_id: fid}) do
    case Ash.get(Caredeck.Services.ServiceMessage, mid,
           tenant: fid,
           authorize?: false
         ) do
      {:ok, %{service_request_id: rid}} -> ~p"/services/requests/#{rid}"
      _ -> ~p"/notifications"
    end
  end

  defp target_path(_), do: ~p"/notifications"

  defp load_notifications(nil, _user), do: []
  defp load_notifications(_facility, nil), do: []

  defp load_notifications(facility, user) do
    Notification
    |> Ash.Query.filter(user_id == ^user.id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(tenant: facility.id, actor: user)
  end

  defp build_lookup(nil, _user), do: %{users: %{}, teams: %{}, residents: %{}}
  defp build_lookup(_facility, nil), do: %{users: %{}, teams: %{}, residents: %{}}

  defp build_lookup(facility, _user) do
    %{
      users: load_users(facility),
      teams: load_teams(),
      residents: load_residents(facility)
    }
  end

  defp load_users(facility) do
    People.Relative
    |> Ash.read!(tenant: facility.id, authorize?: false)
    |> Map.new(fn r -> {r.user_id, r.display_name || "Someone"} end)
  end

  defp load_teams do
    Accounts.TeamIdentity
    |> Ash.read!(authorize?: false)
    |> Map.new(fn t -> {t.id, t.name} end)
  end

  defp load_residents(facility) do
    People.Resident
    |> Ash.read!(tenant: facility.id, authorize?: false)
    |> Map.new(fn r -> {r.id, "#{r.first_name} #{r.last_name}"} end)
  end

  @impl true
  def render(assigns) do
    recent = Enum.filter(assigns.notifications, &within_week?(&1.inserted_at))
    older = Enum.reject(assigns.notifications, &within_week?(&1.inserted_at))

    assigns = assign(assigns, recent: recent, older: older)

    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-2xl px-4 py-6">
        <header class="flex items-center justify-between mb-4">
          <h1 class="text-display-md text-ink-900">Notifications</h1>
          <button
            :if={Enum.any?(@notifications, &is_nil(&1.read_at))}
            type="button"
            phx-click="mark_all_read"
            class="text-brand text-sm hover:text-brand-strong"
          >
            Mark all read
          </button>
        </header>

        <div :if={@notifications == []} class="text-center py-16">
          <svg
            viewBox="0 0 64 64"
            class="mx-auto h-16 w-16 text-ink-300"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M16 26a16 16 0 0 1 32 0v10l4 6H12l4-6V26Z"
            />
            <path stroke-linecap="round" d="M26 48a6 6 0 0 0 12 0" />
          </svg>
          <p class="text-ink-500 text-sm mt-4">No notifications yet.</p>
          <p class="text-ink-300 text-xs mt-1">We'll let you know when there's family news.</p>
        </div>

        <section :if={@recent != []}>
          <p class="text-ink-500 text-xs uppercase tracking-wide mb-2">Recent</p>
          <ul class="bg-card rounded-card shadow-card divide-y divide-divider mb-6">
            <.notification_row :for={n <- @recent} n={n} lookup={@lookup} />
          </ul>
        </section>

        <section :if={@older != []}>
          <p class="text-ink-500 text-xs uppercase tracking-wide mb-2">Older</p>
          <ul class="bg-card rounded-card shadow-card divide-y divide-divider">
            <.notification_row :for={n <- @older} n={n} lookup={@lookup} />
          </ul>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :n, :map, required: true
  attr :lookup, :map, required: true

  defp notification_row(assigns) do
    ~H"""
    <li
      phx-click="open"
      phx-value-id={@n.id}
      class="px-4 py-3 flex items-start gap-3 cursor-pointer hover:bg-page transition"
    >
      <span :if={is_nil(@n.read_at)} class="mt-2 h-2 w-2 rounded-full bg-brand" />
      <span :if={@n.read_at} class="mt-2 h-2 w-2" />

      <div class="h-10 w-10 rounded-full bg-brand-soft text-brand text-sm font-semibold flex items-center justify-center shrink-0">
        {actor_initials(@n, @lookup)}
      </div>

      <div class="flex-1 min-w-0">
        <p class="text-ink-900 text-sm">
          {sentence(@n, @lookup)}
        </p>
        <p class="text-ink-500 text-xs mt-1">{relative_time(@n.inserted_at)}</p>
      </div>

      <img
        :if={@n.thumbnail_url}
        src={"/attachments/" <> @n.thumbnail_url}
        class="h-12 w-12 object-cover rounded-input shrink-0"
        alt=""
      />
    </li>
    """
  end

  defp within_week?(dt), do: DateTime.diff(DateTime.utc_now(), dt, :day) < 7

  defp sentence(n, lookup) do
    Phrasebook.render(%{
      verb: n.verb,
      actor: actor_display(n, lookup),
      target: target_display(n, lookup)
    })
  end

  defp actor_display(%{actor_kind: :user, actor_id: id}, %{users: users}),
    do: Map.get(users, id, "Someone")

  defp actor_display(%{actor_kind: :team, actor_id: id}, %{teams: teams}),
    do: Map.get(teams, id, "A team")

  defp actor_display(_, _), do: "Someone"

  defp target_display(%{target_kind: :post}, _), do: "a resident"

  defp target_display(%{target_kind: :resident, target_id: id}, %{residents: residents}),
    do: Map.get(residents, id, "a resident")

  defp target_display(_, _), do: "a resident"

  defp actor_initials(n, lookup) do
    n
    |> actor_display(lookup)
    |> String.split()
    |> Enum.map(&String.first/1)
    |> Enum.take(2)
    |> Enum.join()
    |> String.upcase()
  end

  defp relative_time(dt) do
    seconds = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      seconds < 60 -> "just now"
      seconds < 3600 -> "#{div(seconds, 60)} min ago"
      seconds < 86_400 -> "#{div(seconds, 3600)} h ago"
      seconds < 604_800 -> "#{div(seconds, 86_400)} d ago"
      true -> Calendar.strftime(dt, "%d %b %Y")
    end
  end
end
