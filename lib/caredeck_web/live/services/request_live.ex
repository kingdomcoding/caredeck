defmodule CaredeckWeb.Services.RequestLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Services.{ServiceMessage, ServiceRequest}

  @impl true
  def mount(%{"request_id" => rid}, _session, socket) do
    facility = socket.assigns[:current_facility]
    actor = current_actor(socket)

    cond do
      is_nil(facility) ->
        {:ok, push_navigate(socket, to: ~p"/feed")}

      true ->
        case load_request(facility, actor, rid) do
          {:ok, request} ->
            if connected?(socket) do
              Phoenix.PubSub.subscribe(Caredeck.PubSub, "services:#{rid}")
            end

            {:ok,
             socket
             |> assign(:page_title, request.summary || request.subkind)
             |> assign(:request, request)
             |> assign(:body, "")}

          _ ->
            {:ok, push_navigate(socket, to: ~p"/services")}
        end
    end
  end

  defp current_actor(socket),
    do: socket.assigns[:current_team] || socket.assigns[:current_user]

  defp load_request(facility, actor, rid) do
    Ash.get(ServiceRequest, rid,
      tenant: facility.id,
      actor: actor,
      load: [:provider, :resident, :attachments, messages: [:attachments]]
    )
  end

  @impl true
  def handle_event("compose", %{"body" => b}, socket),
    do: {:noreply, assign(socket, :body, b)}

  def handle_event("send", %{"body" => body}, socket) do
    facility = socket.assigns.current_facility
    actor = current_actor(socket)
    request = socket.assigns.request

    case ServiceMessage
         |> Ash.Changeset.for_create(
           :create,
           %{
             facility_id: facility.id,
             service_request_id: request.id,
             author_user_id: socket.assigns[:current_user] && socket.assigns.current_user.id,
             author_team_id: socket.assigns[:current_team] && socket.assigns.current_team.id,
             body: body
           },
           tenant: facility.id,
           actor: actor
         )
         |> Ash.create(tenant: facility.id, actor: actor) do
      {:ok, message} ->
        %{
          "event" => "service_message_created",
          "message_id" => message.id,
          "facility_id" => facility.id
        }
        |> Caredeck.Workers.NotificationFanout.new()
        |> Oban.insert()

        {:noreply, socket |> assign(:body, "") |> refresh_request()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Couldn't send reply.")}
    end
  end

  def handle_event("transition", %{"to" => to}, socket) do
    facility = socket.assigns.current_facility
    actor = current_actor(socket)
    new_state = String.to_existing_atom(to)

    case socket.assigns.request
         |> Ash.Changeset.for_update(
           :transition,
           %{state: new_state},
           tenant: facility.id,
           actor: actor
         )
         |> Ash.update(tenant: facility.id, actor: actor) do
      {:ok, _} ->
        {:noreply, refresh_request(socket)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "You can't change the state of this request.")}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "message_created"}, socket),
    do: {:noreply, refresh_request(socket)}

  def handle_info(%Phoenix.Socket.Broadcast{event: "request_updated"}, socket),
    do: {:noreply, refresh_request(socket)}

  def handle_info(_, socket), do: {:noreply, socket}

  defp refresh_request(socket) do
    facility = socket.assigns.current_facility
    actor = current_actor(socket)

    case load_request(facility, actor, socket.assigns.request.id) do
      {:ok, req} -> assign(socket, :request, req)
      _ -> socket
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-2xl px-4 sm:px-6 py-6">
        <header class="mb-4">
          <p class="text-ink-500 text-xs uppercase tracking-wide">
            {@request.provider.name}
          </p>
          <div class="flex items-center justify-between gap-2 flex-wrap">
            <h1 class="text-display-sm text-ink-900">
              {@request.summary || @request.subkind}
            </h1>
            <.state_pill state={@request.state} />
          </div>
        </header>

        <.payload_card request={@request} />

        <section class="mt-6">
          <h2 class="text-ink-900 font-medium mb-2">Conversation</h2>

          <ul class="space-y-2">
            <li :if={@request.messages == []} class="text-ink-500 text-sm text-center py-6">
              No messages yet — write the first reply below.
            </li>
            <li :for={m <- @request.messages} class="bg-card rounded-card shadow-card p-3">
              <p class="text-ink-500 text-xs mb-1">
                {author_label(m)} · {Calendar.strftime(m.inserted_at, "%d %b %H:%M")}
              </p>
              <p class="text-ink-900 text-sm whitespace-pre-wrap">{m.body}</p>
            </li>
          </ul>
        </section>

        <form phx-change="compose" phx-submit="send" class="mt-4 flex gap-2">
          <input
            name="body"
            value={@body}
            placeholder="Write a reply…"
            class="flex-1 rounded-input border border-divider px-3 py-2"
            autocomplete="off"
          />
          <button
            type="submit"
            class="rounded-button bg-brand text-white px-4 py-2 font-medium"
          >
            Send
          </button>
        </form>

        <div :if={@current_team} class="mt-6 flex gap-2 flex-wrap">
          <button
            :if={@request.state == :open}
            type="button"
            phx-click="transition"
            phx-value-to="in_progress"
            class="rounded-button bg-card border border-divider text-ink-900 text-sm px-3 py-2 hover:border-brand"
          >
            Mark in progress
          </button>
          <button
            :if={@request.state in [:open, :in_progress]}
            type="button"
            phx-click="transition"
            phx-value-to="resolved"
            class="rounded-button bg-brand text-white text-sm px-3 py-2 hover:bg-brand-strong"
          >
            Resolve
          </button>
          <button
            :if={@request.state in [:open, :in_progress]}
            type="button"
            phx-click="transition"
            phx-value-to="cancelled"
            class="rounded-button bg-card border border-divider text-ink-500 text-sm px-3 py-2 hover:border-brand"
          >
            Cancel
          </button>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :request, :map, required: true

  defp payload_card(assigns) do
    ~H"""
    <section class="bg-card rounded-card shadow-card p-4">
      <%= case @request.subkind do %>
        <% "prescription_upload" -> %>
          <p class="text-ink-500 text-xs uppercase tracking-wide mb-1">Prescription</p>
          <p
            :if={@request.payload["instructions"] not in [nil, ""]}
            class="text-ink-900 text-sm mb-2"
          >
            {@request.payload["instructions"]}
          </p>
          <img
            :for={a <- @request.attachments}
            src={"/attachments/" <> a.s3_key}
            class="max-h-64 rounded-input"
          />
        <% "complaint" -> %>
          <p class="text-ink-500 text-xs uppercase tracking-wide mb-1">Laundry complaint</p>
          <p class="text-ink-900 text-sm mb-1">
            <strong>Reason:</strong> {@request.payload["reason"]}
          </p>
          <p class="text-ink-900 text-sm mb-2 whitespace-pre-wrap">
            {@request.payload["details"]}
          </p>
          <img
            :for={a <- @request.attachments}
            src={"/attachments/" <> a.s3_key}
            class="max-h-64 rounded-input"
          />
        <% "appointment_request" -> %>
          <p class="text-ink-500 text-xs uppercase tracking-wide mb-1">Appointment</p>
          <p
            :if={@request.payload["preferred_date"] not in [nil, ""]}
            class="text-ink-900 text-sm"
          >
            Preferred date: <strong>{@request.payload["preferred_date"]}</strong>
          </p>
          <p
            :if={@request.payload["haircut_type"] not in [nil, ""]}
            class="text-ink-900 text-sm"
          >
            Style: {@request.payload["haircut_type"]}
          </p>
          <p
            :if={@request.payload["details"] not in [nil, ""]}
            class="text-ink-900 text-sm mt-1 whitespace-pre-wrap"
          >
            {@request.payload["details"]}
          </p>
          <p
            :if={@request.payload["notes"] not in [nil, ""]}
            class="text-ink-900 text-sm mt-1 whitespace-pre-wrap"
          >
            {@request.payload["notes"]}
          </p>
        <% "information_request" -> %>
          <p class="text-ink-500 text-xs uppercase tracking-wide mb-1">Information request</p>
          <p class="text-ink-900 text-sm whitespace-pre-wrap">{@request.payload["details"]}</p>
        <% "medication_inquiry" -> %>
          <p class="text-ink-500 text-xs uppercase tracking-wide mb-1">Medication inquiry</p>
          <p class="text-ink-900 text-sm mb-1">
            <strong>{@request.payload["medication_name"]}</strong>
          </p>
          <p class="text-ink-900 text-sm whitespace-pre-wrap">
            {@request.payload["question"]}
          </p>
        <% "general_question" -> %>
          <p class="text-ink-500 text-xs uppercase tracking-wide mb-1">Question</p>
          <p class="text-ink-900 text-sm whitespace-pre-wrap">
            {@request.payload["question"]}
          </p>
        <% _ -> %>
          <pre class="text-xs text-ink-500">{Jason.encode!(@request.payload, pretty: true)}</pre>
      <% end %>
    </section>
    """
  end

  attr :state, :atom, required: true

  defp state_pill(assigns) do
    ~H"""
    <span class={[
      "text-xs font-medium rounded-full px-2 py-0.5",
      @state == :open && "bg-brand-soft text-brand",
      @state == :in_progress && "bg-yellow-100 text-yellow-700",
      @state == :resolved && "bg-green-100 text-green-700",
      @state == :cancelled && "bg-page text-ink-500"
    ]}>
      {humanize_state(@state)}
    </span>
    """
  end

  defp humanize_state(:open), do: "Open"
  defp humanize_state(:in_progress), do: "In progress"
  defp humanize_state(:resolved), do: "Resolved"
  defp humanize_state(:cancelled), do: "Cancelled"

  defp author_label(%{author_team_id: tid}) when not is_nil(tid), do: "Team reply"
  defp author_label(%{author_user_id: uid}) when not is_nil(uid), do: "Family"
  defp author_label(_), do: "—"
end
