defmodule CaredeckWeb.PostLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Feed.{Comment, Post}
  alias Caredeck.People
  alias Caredeck.Tenancy
  alias CaredeckWeb.Endpoint

  require Ash.Query

  @load [
    :team_identity,
    :attachments,
    :resident_tags,
    :reactions,
    audience: [],
    comments: [:author]
  ]

  @impl true
  def mount(%{"post_id" => id}, _session, socket) do
    facility = socket.assigns.current_facility
    actor = current_actor(socket)

    if connected?(socket) and facility do
      Endpoint.subscribe("facility:#{facility.id}:feed")
    end

    post = load_post(facility, id, actor)

    if post do
      relationships = load_relationships(facility, post)

      {:ok,
       socket
       |> assign(:page_title, "Post")
       |> assign(:post, post)
       |> assign(:relationships, relationships)
       |> assign(:body, "")}
    else
      {:ok,
       socket
       |> put_flash(:error, "Post not found.")
       |> push_navigate(to: ~p"/feed")}
    end
  end

  @impl true
  def handle_event("comment", %{"body" => body}, socket) do
    body = String.trim(body)
    facility = socket.assigns.current_facility
    user = socket.assigns.current_user

    cond do
      body == "" ->
        {:noreply, socket}

      is_nil(user) ->
        {:noreply, put_flash(socket, :error, "Sign in as a relative to comment.")}

      true ->
        Comment
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: facility.id,
            post_id: socket.assigns.post.id,
            author_user_id: user.id,
            body: body
          },
          tenant: facility.id,
          actor: user
        )
        |> Ash.create!(tenant: facility.id, actor: user)

        post = load_post(facility, socket.assigns.post.id, user)
        relationships = load_relationships(facility, post)

        {:noreply,
         socket
         |> assign(:post, post)
         |> assign(:relationships, relationships)
         |> assign(:body, "")}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: event, payload: payload}, socket)
      when event in ["post_updated", "post_deleted"] do
    facility = socket.assigns.current_facility
    actor = current_actor(socket)

    cond do
      event == "post_deleted" and payload[:id] == socket.assigns.post.id ->
        {:noreply, push_navigate(socket, to: ~p"/feed")}

      event == "post_updated" ->
        post = load_post(facility, socket.assigns.post.id, actor)
        {:noreply, assign(socket, :post, post)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info(%Phoenix.Socket.Broadcast{}, socket), do: {:noreply, socket}

  defp current_actor(socket) do
    socket.assigns[:current_user] || socket.assigns[:current_team]
  end

  defp load_post(nil, _id, _actor), do: nil
  defp load_post(_facility, _id, nil), do: nil

  defp load_post(facility, id, actor) do
    case Ash.get(Post, id, tenant: Tenancy.to_tenant(facility), load: @load, actor: actor) do
      {:ok, post} -> post
      _ -> nil
    end
  end

  defp load_relationships(facility, post) do
    audience_ids = Enum.map(post.audience, & &1.id)
    comment_user_ids = Enum.map(post.comments, & &1.author_user_id)

    if audience_ids == [] or comment_user_ids == [] do
      %{}
    else
      relatives =
        People.Relative
        |> Ash.Query.filter(user_id in ^comment_user_ids)
        |> Ash.read!(tenant: facility.id, authorize?: false)

      relative_by_user = Map.new(relatives, &{&1.user_id, &1})
      relative_ids = Map.values(relative_by_user) |> Enum.map(& &1.id)

      if relative_ids == [] do
        %{}
      else
        links =
          People.RelativeOfResident
          |> Ash.Query.filter(relative_id in ^relative_ids and resident_id in ^audience_ids)
          |> Ash.read!(tenant: facility.id, authorize?: false)

        rel_by_relative = Map.new(links, &{&1.relative_id, &1.relationship})

        Map.new(comment_user_ids, fn user_id ->
          case Map.fetch(relative_by_user, user_id) do
            {:ok, relative} -> {user_id, Map.get(rel_by_relative, relative.id)}
            _ -> {user_id, nil}
          end
        end)
      end
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
      <div class="mx-auto max-w-2xl px-4 py-6 pb-24">
        <.link navigate={~p"/feed"} class="text-ink-500 hover:text-ink-900 text-sm">
          &larr; Back to feed
        </.link>

        <article class="bg-card rounded-card shadow-card my-4 overflow-hidden">
          <header class="px-4 pt-4">
            <p class="text-ink-900 font-medium">{@post.team_identity.name}</p>
            <p class="text-ink-500 text-xs">{format_time(@post.inserted_at)}</p>
          </header>
          <p class="px-4 py-3 text-ink-900 whitespace-pre-wrap">{@post.body}</p>

          <div
            :if={@post.attachments != []}
            class={["grid gap-1 bg-page", grid_classes(length(@post.attachments))]}
          >
            <div :for={att <- Enum.take(@post.attachments, 4)} class="relative overflow-hidden">
              <img src={"/attachments/" <> att.s3_key} class="h-full w-full object-cover" alt="" />
            </div>
          </div>
        </article>

        <section class="bg-card rounded-card shadow-card p-4 mb-4">
          <h2 class="text-display-sm text-ink-900 mb-3">Comments ({length(@post.comments)})</h2>

          <p :if={@post.comments == []} class="text-ink-500 text-sm">
            No comments yet. Be the first.
          </p>

          <ul class="divide-y divide-divider">
            <li :for={comment <- @post.comments} class="py-3">
              <p class="text-ink-900 text-sm font-medium">
                {comment.author.email}
                <span
                  :if={label = relationship_label(@relationships, comment.author_user_id)}
                  class="text-ink-500 font-normal"
                >
                  &middot; {label}
                </span>
              </p>
              <p class="text-ink-900 text-sm mt-1 whitespace-pre-wrap">{comment.body}</p>
              <p class="text-ink-500 text-xs mt-1">{format_time(comment.inserted_at)}</p>
            </li>
          </ul>

          <form
            :if={@current_user}
            phx-submit="comment"
            class="mt-4 flex items-start gap-2"
          >
            <textarea
              name="body"
              rows="2"
              placeholder="Write a comment…"
              class="flex-1 rounded-input border border-divider px-3 py-2 text-sm text-ink-900 focus:outline-none focus:ring-2 focus:ring-brand"
            >{@body}</textarea>
            <button
              type="submit"
              class="rounded-button bg-brand text-white px-4 py-2 text-sm"
            >
              Send
            </button>
          </form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp grid_classes(1), do: "grid-cols-1 aspect-square"
  defp grid_classes(2), do: "grid-cols-2 aspect-[2/1]"
  defp grid_classes(3), do: "grid-cols-2 grid-rows-2 aspect-square [&>*:first-child]:row-span-2"
  defp grid_classes(_), do: "grid-cols-2 grid-rows-2 aspect-square"

  defp relationship_label(map, user_id) do
    case Map.get(map, user_id) do
      nil -> nil
      atom -> atom |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
    end
  end

  defp format_time(dt), do: Calendar.strftime(dt, "%d %b %Y · %H:%M")
end
