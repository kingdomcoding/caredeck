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
       |> assign(:body, "")
       |> assign(:show_likers, false)
       |> assign(:likers, [])
       |> assign(:editing_comment_id, nil)}
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
  def handle_event("toggle_reaction", %{"post-id" => post_id}, socket) do
    user = socket.assigns[:current_user]
    facility = socket.assigns.current_facility

    if user && facility do
      Caredeck.Feed.Reaction
      |> Ash.ActionInput.for_action(
        :toggle,
        %{facility_id: facility.id, post_id: post_id},
        actor: user,
        tenant: facility.id
      )
      |> Ash.run_action()
    end

    post = load_post(facility, socket.assigns.post.id, current_actor(socket))
    relationships = load_relationships(facility, post)
    {:noreply, socket |> assign(:post, post) |> assign(:relationships, relationships)}
  end

  def handle_event("edit_comment", %{"id" => id}, socket) do
    {:noreply, assign(socket, :editing_comment_id, id)}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, :editing_comment_id, nil)}
  end

  def handle_event("save_comment", %{"comment_id" => id, "body" => body}, socket) do
    facility = socket.assigns.current_facility
    user = socket.assigns.current_user

    case Ash.get(Caredeck.Feed.Comment, id, tenant: facility.id, actor: user) do
      {:ok, comment} ->
        result =
          comment
          |> Ash.Changeset.for_update(:update, %{body: String.trim(body)},
            tenant: facility.id,
            actor: user
          )
          |> Ash.update()

        case result do
          {:ok, _} ->
            post = load_post(facility, socket.assigns.post.id, user)
            relationships = load_relationships(facility, post)

            {:noreply,
             socket
             |> assign(:post, post)
             |> assign(:relationships, relationships)
             |> assign(:editing_comment_id, nil)}

          {:error, _err} ->
            {:noreply,
             socket
             |> put_flash(:error, "Edit window has closed.")
             |> assign(:editing_comment_id, nil)}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Comment not found.")}
    end
  end

  def handle_event("delete_comment", %{"id" => id}, socket) do
    facility = socket.assigns.current_facility
    user = socket.assigns.current_user

    case Ash.get(Caredeck.Feed.Comment, id, tenant: facility.id, actor: user) do
      {:ok, comment} ->
        Ash.destroy!(comment, tenant: facility.id, actor: user)
        post = load_post(facility, socket.assigns.post.id, user)
        relationships = load_relationships(facility, post)

        {:noreply,
         socket
         |> assign(:post, post)
         |> assign(:relationships, relationships)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("show_likers", _params, socket) do
    facility = socket.assigns.current_facility
    actor = current_actor(socket)
    post = Ash.load!(socket.assigns.post, [reactions: [:user]], tenant: facility.id, actor: actor)
    likers = Enum.map(post.reactions, & &1.user)
    {:noreply, socket |> assign(:show_likers, true) |> assign(:likers, likers)}
  end

  def handle_event("hide_likers", _params, socket) do
    {:noreply, assign(socket, :show_likers, false)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: event, payload: payload}, socket)
      when event in ["post_updated", "post_deleted", "reaction_changed"] do
    facility = socket.assigns.current_facility
    actor = current_actor(socket)

    cond do
      event == "post_deleted" and payload[:id] == socket.assigns.post.id ->
        {:noreply, push_navigate(socket, to: ~p"/feed")}

      event in ["post_updated", "reaction_changed"] ->
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

          <% photos = Enum.filter(@post.attachments, &(&1.kind == :photo)) %>
          <% audios = Enum.filter(@post.attachments, &(&1.kind == :audio)) %>

          <div :if={photos != []} class={["grid gap-1 bg-page", grid_classes(length(photos))]}>
            <div :for={att <- Enum.take(photos, 4)} class="relative overflow-hidden">
              <img src={"/attachments/" <> att.s3_key} class="h-full w-full object-cover" alt="" />
            </div>
          </div>

          <div :if={audios != []} class="px-4 py-3 space-y-2 bg-card border-t border-divider">
            <audio
              :for={a <- audios}
              src={"/attachments/" <> a.s3_key}
              controls
              preload="metadata"
              class="w-full"
            >
            </audio>
          </div>

          <div class="px-4 py-3 flex items-center gap-4 text-ink-500 text-sm border-t border-divider">
            <button
              :if={@current_user}
              type="button"
              phx-click="toggle_reaction"
              phx-value-post-id={@post.id}
              class={[
                "flex items-center gap-1 hover:text-like-red transition",
                liked_by_actor?(@post, @current_user) && "text-like-red"
              ]}
            >
              {if liked_by_actor?(@post, @current_user), do: "❤", else: "♡"}
              <span>{length(@post.reactions)} likes</span>
            </button>
            <button
              type="button"
              phx-click="show_likers"
              class="hover:text-ink-900"
            >
              View likes
            </button>
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

              <%= if @editing_comment_id == comment.id do %>
                <form phx-submit="save_comment" class="mt-1 flex items-start gap-2">
                  <input type="hidden" name="comment_id" value={comment.id} />
                  <textarea
                    name="body"
                    rows="2"
                    class="flex-1 rounded-input border border-divider px-3 py-2 text-sm text-ink-900 focus:outline-none focus:ring-2 focus:ring-brand"
                  >{comment.body}</textarea>
                  <button type="submit" class="rounded-button bg-brand text-white px-3 py-2 text-sm">
                    Save
                  </button>
                  <button type="button" phx-click="cancel_edit" class="text-ink-500 text-sm px-2">
                    Cancel
                  </button>
                </form>
              <% else %>
                <p class="text-ink-900 text-sm mt-1 whitespace-pre-wrap">{comment.body}</p>
                <p class="text-ink-500 text-xs mt-1">
                  {format_time(comment.inserted_at)}
                  <span :if={comment.edited_at}>· edited</span>
                  <button
                    :if={can_edit_comment?(comment, @current_user)}
                    type="button"
                    phx-click="edit_comment"
                    phx-value-id={comment.id}
                    class="ml-2 text-brand hover:text-brand-strong"
                  >
                    Edit
                  </button>
                  <button
                    :if={can_delete_comment?(comment, @current_user)}
                    type="button"
                    phx-click="delete_comment"
                    phx-value-id={comment.id}
                    phx-confirm="Delete this comment?"
                    class="ml-2 text-ink-500 hover:text-like-red"
                  >
                    Delete
                  </button>
                </p>
              <% end %>
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
              type="button"
              phx-click="toggle_reaction"
              phx-value-post-id={@post.id}
              class={[
                "rounded-button bg-card border border-divider px-3 py-2 text-lg hover:text-like-red",
                liked_by_actor?(@post, @current_user) && "text-like-red"
              ]}
              aria-label="Toggle like"
            >
              {if liked_by_actor?(@post, @current_user), do: "❤", else: "♡"}
            </button>
            <button
              type="submit"
              class="rounded-button bg-brand text-white px-4 py-2 text-sm"
            >
              Send
            </button>
          </form>
        </section>

        <div
          :if={@show_likers}
          phx-click-away="hide_likers"
          class="fixed inset-0 bg-black/40 flex items-center justify-center z-20"
        >
          <div class="bg-card rounded-card shadow-card p-6 max-w-sm w-full mx-4">
            <h2 class="text-display-sm text-ink-900 mb-3">Liked by</h2>
            <p :if={@likers == []} class="text-ink-500 text-sm">No likes yet.</p>
            <ul class="divide-y divide-divider max-h-80 overflow-y-auto">
              <li :for={user <- @likers} class="py-2 text-ink-900 text-sm">
                {user.email}
              </li>
            </ul>
            <button
              type="button"
              phx-click="hide_likers"
              class="mt-4 rounded-button bg-brand text-white px-4 py-2 text-sm w-full"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp liked_by_actor?(_post, nil), do: false

  defp liked_by_actor?(post, user) do
    Enum.any?(post.reactions, &(&1.user_id == user.id))
  end

  defp can_edit_comment?(_comment, nil), do: false

  defp can_edit_comment?(comment, user) do
    comment.author_user_id == user.id and
      DateTime.diff(DateTime.utc_now(), comment.inserted_at, :second) <= 300
  end

  defp can_delete_comment?(_comment, nil), do: false

  defp can_delete_comment?(comment, user), do: comment.author_user_id == user.id

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
