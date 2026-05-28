defmodule CaredeckWeb.FeedLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Feed.Post
  alias Caredeck.Tenancy
  alias CaredeckWeb.Endpoint

  @load [
    :team_identity,
    :attachments,
    :resident_tags,
    :reactions,
    comments: [:author]
  ]

  @impl true
  def mount(_params, _session, socket) do
    facility = socket.assigns.current_facility

    if connected?(socket) and facility do
      Endpoint.subscribe("facility:#{facility.id}:feed")
    end

    {:ok,
     socket
     |> assign(:page_title, "Feed")
     |> assign(:posts, load_posts(facility))}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: event}, socket)
      when event in ["post_created", "post_updated", "post_deleted"] do
    {:noreply, assign(socket, posts: load_posts(socket.assigns.current_facility))}
  end

  defp load_posts(nil), do: []

  defp load_posts(facility) do
    Post
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(tenant: Tenancy.to_tenant(facility), load: @load, authorize?: false)
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
        <h1 class="text-display-md text-ink-900 mb-2">Feed</h1>
        <p :if={@current_facility} class="text-ink-500 mb-6">{@current_facility.name}</p>
        <p :if={!@current_facility} class="text-ink-500 mb-6">No facility</p>

        <p :if={@posts == []} class="text-ink-500 text-sm py-12 text-center">
          No posts yet.
        </p>

        <article :for={post <- @posts} class="bg-card rounded-card shadow-card mb-4 overflow-hidden">
          <.post_header post={post} />
          <.post_body post={post} />
          <.attachment_grid attachments={post.attachments} />
          <.tag_chips tags={post.resident_tags} />
          <.engagement_line post={post} />
        </article>
      </div>

      <.link
        :if={@current_team}
        navigate={~p"/feed/compose"}
        class="fixed bottom-6 right-6 inline-flex h-14 w-14 items-center justify-center rounded-full bg-brand text-white text-display-sm shadow-card"
      >
        +
      </.link>
    </Layouts.app>
    """
  end

  attr :post, :map, required: true

  defp post_header(assigns) do
    ~H"""
    <header class="flex items-start justify-between px-4 pt-4">
      <div class="flex items-center gap-3">
        <div class="h-10 w-10 rounded-full bg-brand-soft text-brand text-sm font-semibold flex items-center justify-center">
          {team_initials(@post.team_identity.name)}
        </div>
        <div>
          <p class="text-ink-900 font-medium leading-tight">{@post.team_identity.name}</p>
          <p class="text-ink-500 text-xs">{format_time(@post.inserted_at)}</p>
        </div>
      </div>
    </header>
    """
  end

  attr :post, :map, required: true

  defp post_body(assigns) do
    ~H"""
    <p class="px-4 py-3 text-ink-900 whitespace-pre-wrap">{@post.body}</p>
    """
  end

  attr :attachments, :list, required: true

  defp attachment_grid(assigns) do
    photos = Enum.filter(assigns.attachments, &(&1.kind == :photo))
    layout = photo_layout(length(photos))
    visible = Enum.take(photos, layout.visible)
    overflow = max(length(photos) - layout.visible, 0)

    assigns =
      assign(assigns,
        photos: photos,
        layout: layout,
        visible: visible,
        overflow: overflow
      )

    ~H"""
    <div :if={@photos != []} class={["grid gap-1 bg-page", @layout.classes]}>
      <div
        :for={{photo, idx} <- Enum.with_index(@visible)}
        class="relative overflow-hidden"
      >
        <img src={~p"/attachments/#{photo.s3_key}"} class="h-full w-full object-cover" alt="" />
        <div
          :if={@overflow > 0 and idx == @layout.visible - 1}
          class="absolute inset-0 bg-black/40 flex items-center justify-center text-white text-display-sm"
        >
          +{@overflow}
        </div>
      </div>
    </div>
    """
  end

  defp photo_layout(1), do: %{classes: "grid-cols-1 aspect-square", visible: 1}
  defp photo_layout(2), do: %{classes: "grid-cols-2 aspect-[2/1]", visible: 2}

  defp photo_layout(3),
    do: %{
      classes: "grid-cols-2 grid-rows-2 aspect-square [&>*:first-child]:row-span-2",
      visible: 3
    }

  defp photo_layout(_n), do: %{classes: "grid-cols-2 grid-rows-2 aspect-square", visible: 4}

  attr :tags, :list, required: true

  defp tag_chips(assigns) do
    {first, second, overflow} =
      case assigns.tags do
        [] -> {nil, nil, 0}
        [a] -> {a, nil, 0}
        [a, b] -> {a, b, 0}
        [a, b | rest] -> {a, b, length(rest)}
      end

    assigns = assign(assigns, first: first, second: second, overflow: overflow)

    ~H"""
    <p :if={@tags != []} class="px-4 pt-3 text-ink-500 text-sm">
      &#x2764;
      <span :if={@first} class="text-ink-900">{@first.first_name} {@first.last_name}</span><span :if={
        @second
      }>, <span class="text-ink-900">{@second.first_name} {@second.last_name}</span></span><span :if={
        @overflow > 0
      }> and {@overflow} more</span>
    </p>
    """
  end

  attr :post, :map, required: true

  defp engagement_line(assigns) do
    likes = length(assigns.post.reactions)
    comments = length(assigns.post.comments)
    assigns = assign(assigns, likes: likes, comments: comments)

    ~H"""
    <div class="px-4 py-3 flex items-center gap-4 text-ink-500 text-sm border-t border-divider">
      <span>&#x2764; {@likes} {if @likes == 1, do: "like", else: "likes"}</span>
      <.link navigate={~p"/feed/#{@post.id}"} class="hover:text-ink-900">
        &#x1F4AC; {@comments} {if @comments == 1, do: "comment", else: "comments"}
      </.link>
    </div>
    """
  end

  defp team_initials(name) do
    name
    |> String.split()
    |> Enum.map(&String.first/1)
    |> Enum.take(2)
    |> Enum.join()
  end

  defp format_time(dt), do: Calendar.strftime(dt, "%d %b %Y · %H:%M")
end
