defmodule CaredeckWeb.PostComposeLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Feed
  alias Caredeck.Feed.{Attachment, Post, PostAudience, ResidentTagOnPost}
  alias Caredeck.People

  @upload_opts [
    accept: ~w(.jpg .jpeg .png),
    max_entries: 9,
    max_file_size: 10_000_000
  ]

  @audio_upload_opts [
    accept: :any,
    max_entries: 1,
    max_file_size: 8_000_000
  ]

  @video_upload_opts [
    accept: ~w(.mp4 .mov .webm),
    max_entries: 2,
    max_file_size: 50_000_000
  ]

  @impl true
  def mount(%{"edit_post_id" => id}, _session, socket) do
    facility = socket.assigns.current_facility
    team = socket.assigns.current_team

    case load_post(facility, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Post not found.")
         |> push_navigate(to: ~p"/feed")}

      %{team_identity_id: tid} = post when tid != nil and team != nil and tid == team.id ->
        {:ok,
         socket
         |> assign(:mode, :edit)
         |> assign(:post, post)
         |> assign(:body, post.body)
         |> assign(:is_internal, post.is_internal)
         |> assign(:residents, residents(facility))
         |> assign(:audience_ids, MapSet.new(Enum.map(post.audience, & &1.id)))
         |> assign(:tag_ids, MapSet.new(Enum.map(post.resident_tags, & &1.id)))
         |> assign(:existing_attachments, post.attachments)
         |> assign(:audio_duration_sec, 0)
         |> assign(:page_title, "Edit post")
         |> allow_upload(:photos, @upload_opts)
         |> allow_upload(:audio_notes, @audio_upload_opts)
         |> allow_upload(:videos, @video_upload_opts)}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "You can only edit your own team's posts.")
         |> push_navigate(to: ~p"/feed")}
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    facility = socket.assigns.current_facility

    {:ok,
     socket
     |> assign(:mode, :new)
     |> assign(:post, nil)
     |> assign(:body, "")
     |> assign(:is_internal, false)
     |> assign(:residents, residents(facility))
     |> assign(:audience_ids, MapSet.new())
     |> assign(:tag_ids, MapSet.new())
     |> assign(:existing_attachments, [])
     |> assign(:audio_duration_sec, 0)
     |> assign(:page_title, "New post")
     |> allow_upload(:photos, @upload_opts)
     |> allow_upload(:audio_notes, @audio_upload_opts)
     |> allow_upload(:videos, @video_upload_opts)}
  end

  defp residents(nil), do: []

  defp residents(facility) do
    People.Resident
    |> Ash.Query.sort(last_name: :asc, first_name: :asc)
    |> Ash.read!(tenant: facility.id, authorize?: false)
  end

  defp load_post(nil, _id), do: nil

  defp load_post(facility, id) do
    case Ash.get(Post, id,
           tenant: facility.id,
           load: [:audience, :resident_tags, :attachments],
           authorize?: false
         ) do
      {:ok, post} -> post
      _ -> nil
    end
  end

  @impl true
  def handle_event("validate", params, socket) do
    body = Map.get(params, "body", socket.assigns.body)
    is_internal? = Map.get(params, "is_internal") == "true"
    {:noreply, assign(socket, body: body, is_internal: is_internal?)}
  end

  def handle_event("toggle_all_audience", _params, socket) do
    all = MapSet.new(Enum.map(socket.assigns.residents, & &1.id))

    next =
      if MapSet.equal?(socket.assigns.audience_ids, all) do
        MapSet.new()
      else
        all
      end

    tag_ids =
      if MapSet.equal?(socket.assigns.tag_ids, socket.assigns.audience_ids) do
        next
      else
        MapSet.intersection(socket.assigns.tag_ids, next)
      end

    {:noreply, assign(socket, audience_ids: next, tag_ids: tag_ids)}
  end

  def handle_event("toggle_audience", %{"id" => id}, socket) do
    audience_ids =
      if MapSet.member?(socket.assigns.audience_ids, id) do
        MapSet.delete(socket.assigns.audience_ids, id)
      else
        MapSet.put(socket.assigns.audience_ids, id)
      end

    tag_ids = MapSet.intersection(socket.assigns.tag_ids, audience_ids)

    {:noreply, assign(socket, audience_ids: audience_ids, tag_ids: tag_ids)}
  end

  def handle_event("remove_attachment", %{"id" => attachment_id}, socket) do
    facility = socket.assigns.current_facility
    team = socket.assigns.current_team

    case Ash.get(Attachment, attachment_id, tenant: facility.id, actor: team) do
      {:ok, attachment} ->
        hard_delete(Attachment, Attachment.Version, [attachment.id])

        existing = Enum.reject(socket.assigns.existing_attachments, &(&1.id == attachment_id))
        {:noreply, assign(socket, :existing_attachments, existing)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("cancel_video", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :videos, ref)}
  end

  def handle_event("audio_recorded", %{"duration_sec" => seconds}, socket) do
    {:noreply, assign(socket, :audio_duration_sec, seconds)}
  end

  def handle_event("discard_audio", _params, socket) do
    socket =
      Enum.reduce(socket.assigns.uploads.audio_notes.entries, socket, fn entry, acc ->
        cancel_upload(acc, :audio_notes, entry.ref)
      end)

    {:noreply, assign(socket, :audio_duration_sec, 0)}
  end

  def handle_event("toggle_tag", %{"id" => id}, socket) do
    if MapSet.member?(socket.assigns.audience_ids, id) do
      tag_ids =
        if MapSet.member?(socket.assigns.tag_ids, id) do
          MapSet.delete(socket.assigns.tag_ids, id)
        else
          MapSet.put(socket.assigns.tag_ids, id)
        end

      {:noreply, assign(socket, tag_ids: tag_ids)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("send", params, socket) do
    body = params |> Map.get("body", "") |> String.trim()
    is_internal? = Map.get(params, "is_internal") == "true"
    facility = socket.assigns.current_facility
    team = socket.assigns.current_team

    cond do
      body == "" ->
        {:noreply, put_flash(socket, :error, "Add some words before sending.")}

      is_nil(facility) or is_nil(team) ->
        {:noreply, put_flash(socket, :error, "Sign in with a team to post.")}

      true ->
        post = persist_post(socket, body, is_internal?, facility, team)
        sync_audience(post, socket.assigns.audience_ids, facility, team)
        sync_tags(post, socket.assigns.tag_ids, facility, team)
        upload_attachments(socket, post, facility, team)
        upload_audio(socket, post, facility, team)
        upload_videos(socket, post, facility, team)
        enqueue_post_fanout(socket, post)

        {:noreply,
         socket
         |> put_flash(:info, "Post sent.")
         |> push_navigate(to: ~p"/feed")}
    end
  end

  defp enqueue_post_fanout(%{assigns: %{mode: :new}}, post) do
    %{event: "post_created", post_id: post.id, facility_id: post.facility_id}
    |> Caredeck.Workers.NotificationFanout.new()
    |> Oban.insert()
  end

  defp enqueue_post_fanout(_, _), do: :ok

  defp upload_videos(socket, post, facility, team) do
    consume_uploaded_entries(socket, :videos, fn %{path: path}, entry ->
      key = Feed.S3.generate_key("videos", entry.client_name)
      {:ok, body} = File.read(path)
      {:ok, _} = Feed.S3.put_object(key, body, entry.client_type)

      Attachment
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          post_id: post.id,
          kind: :video,
          s3_key: key,
          mime_type: entry.client_type,
          bytes: entry.client_size,
          position: 50
        },
        tenant: facility.id,
        actor: team
      )
      |> Ash.create!(tenant: facility.id, actor: team)

      {:ok, key}
    end)
  end

  defp upload_audio(socket, post, facility, team) do
    duration = socket.assigns.audio_duration_sec

    consume_uploaded_entries(socket, :audio_notes, fn %{path: path}, entry ->
      key = Feed.S3.generate_key("audios", entry.client_name)
      {:ok, body} = File.read(path)
      {:ok, _} = Feed.S3.put_object(key, body, entry.client_type)

      Attachment
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          post_id: post.id,
          kind: :audio,
          s3_key: key,
          mime_type: entry.client_type,
          bytes: entry.client_size,
          duration_sec: duration,
          position: 99
        },
        tenant: facility.id,
        actor: team
      )
      |> Ash.create!(tenant: facility.id, actor: team)

      {:ok, key}
    end)
  end

  defp persist_post(%{assigns: %{mode: :new}}, body, is_internal?, facility, team) do
    Post
    |> Ash.Changeset.for_create(
      :create,
      %{
        facility_id: facility.id,
        team_identity_id: team.id,
        body: body,
        is_internal: is_internal?
      },
      tenant: facility.id,
      actor: team
    )
    |> Ash.create!(tenant: facility.id, actor: team)
  end

  defp persist_post(%{assigns: %{mode: :edit, post: post}}, body, is_internal?, facility, team) do
    post
    |> Ash.Changeset.for_update(:update, %{body: body, is_internal: is_internal?},
      tenant: facility.id,
      actor: team
    )
    |> Ash.update!(tenant: facility.id, actor: team)
  end

  defp sync_audience(post, audience_ids, facility, team) do
    import Ecto.Query

    existing =
      from(a in PostAudience, where: a.post_id == ^post.id) |> Caredeck.Repo.all()

    existing_by_resident = Map.new(existing, &{&1.resident_id, &1.id})
    existing_ids = MapSet.new(Map.keys(existing_by_resident))
    desired_ids = audience_ids

    to_remove = MapSet.difference(existing_ids, desired_ids) |> MapSet.to_list()
    to_add = MapSet.difference(desired_ids, existing_ids) |> MapSet.to_list()

    if to_remove != [] do
      removed_row_ids = Enum.map(to_remove, &Map.fetch!(existing_by_resident, &1))
      hard_delete(PostAudience, PostAudience.Version, removed_row_ids)
    end

    Enum.each(to_add, fn rid ->
      PostAudience
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, post_id: post.id, resident_id: rid},
        tenant: facility.id,
        actor: team
      )
      |> Ash.create!(tenant: facility.id, actor: team)
    end)
  end

  defp sync_tags(post, tag_ids, facility, team) do
    import Ecto.Query

    existing =
      from(t in ResidentTagOnPost, where: t.post_id == ^post.id) |> Caredeck.Repo.all()

    existing_by_resident = Map.new(existing, &{&1.resident_id, &1.id})
    existing_ids = MapSet.new(Map.keys(existing_by_resident))
    desired_ids = tag_ids

    to_remove = MapSet.difference(existing_ids, desired_ids) |> MapSet.to_list()
    to_add = MapSet.difference(desired_ids, existing_ids) |> MapSet.to_list()

    if to_remove != [] do
      removed_row_ids = Enum.map(to_remove, &Map.fetch!(existing_by_resident, &1))
      hard_delete(ResidentTagOnPost, ResidentTagOnPost.Version, removed_row_ids)
    end

    Enum.each(to_add, fn rid ->
      ResidentTagOnPost
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, post_id: post.id, resident_id: rid},
        tenant: facility.id,
        actor: team
      )
      |> Ash.create!(tenant: facility.id, actor: team)
    end)
  end

  defp hard_delete(_schema, _version_schema, []), do: :ok

  defp hard_delete(schema, version_schema, ids) do
    import Ecto.Query

    from(v in version_schema, where: v.version_source_id in ^ids)
    |> Caredeck.Repo.delete_all()

    from(r in schema, where: r.id in ^ids)
    |> Caredeck.Repo.delete_all()

    :ok
  end

  defp upload_attachments(socket, post, facility, team) do
    Application.put_env(:caredeck, :thumbnailer_mode, :sync)

    uploaded =
      consume_uploaded_entries(socket, :photos, fn %{path: path}, entry ->
        key = Feed.S3.generate_key("photos", entry.client_name)
        {:ok, body} = File.read(path)
        {:ok, _} = Feed.S3.put_object(key, body, entry.client_type)

        {:ok,
         %{key: key, mime: entry.client_type, bytes: entry.client_size, name: entry.client_name}}
      end)

    uploaded
    |> Enum.with_index()
    |> Enum.each(fn {%{key: key, mime: mime, bytes: bytes}, idx} ->
      Attachment
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          post_id: post.id,
          kind: :photo,
          s3_key: key,
          mime_type: mime,
          bytes: bytes,
          position: idx
        },
        tenant: facility.id,
        actor: team
      )
      |> Ash.create!(tenant: facility.id, actor: team)
    end)
  end

  defp audience_state(audience_ids, residents) do
    cond do
      MapSet.size(audience_ids) == 0 -> :none
      MapSet.size(audience_ids) == length(residents) -> :all
      true -> :partial
    end
  end

  @impl true
  def render(assigns) do
    audience_state = audience_state(assigns.audience_ids, assigns.residents)
    assigns = assign(assigns, :audience_state, audience_state)

    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_team={@current_team}
    >
      <div class="mx-auto max-w-2xl px-4 py-6 pb-24">
        <div class="flex items-center justify-between mb-4">
          <.link navigate={~p"/feed"} class="text-ink-500 hover:text-ink-900 text-sm">
            &larr; Cancel
          </.link>
          <h1 class="text-display-sm text-ink-900">
            {if @mode == :edit, do: "Edit post", else: "New post"}
          </h1>
          <button
            type="submit"
            form="compose-form"
            class="rounded-button bg-brand text-white px-4 py-2 text-sm"
          >
            Send post
          </button>
        </div>

        <form id="compose-form" phx-submit="send" phx-change="validate">
          <textarea
            name="body"
            rows="6"
            placeholder="What's happening today?"
            class="w-full rounded-input border border-divider px-3 py-2 text-ink-900 mb-4 focus:outline-none focus:ring-2 focus:ring-brand"
          >{@body}</textarea>

          <label class="flex items-center gap-2 mb-4 text-ink-900 cursor-pointer select-none">
            <input
              type="checkbox"
              name="is_internal"
              value="true"
              checked={@is_internal}
              class="sr-only peer"
            />
            <span class="h-5 w-5 rounded-input border-2 border-divider flex items-center justify-center text-white text-xs font-bold transition peer-checked:bg-brand peer-checked:border-brand peer-checked:[&>span]:opacity-100">
              <span class="opacity-0">&#x2713;</span>
            </span>
            <span class="text-sm">Internal post (team only)</span>
          </label>

          <section class="mb-4">
            <h2 class="text-ink-900 font-medium mb-2">Photos</h2>

            <div :if={@existing_attachments != []} class="flex gap-2 mb-3 flex-wrap">
              <article
                :for={att <- @existing_attachments}
                class="relative w-20 h-20 group"
              >
                <img
                  src={"/attachments/" <> att.s3_key}
                  class="w-20 h-20 object-cover rounded-input border border-divider"
                  alt=""
                />
                <button
                  type="button"
                  phx-click="remove_attachment"
                  phx-value-id={att.id}
                  phx-confirm="Remove this photo from the post?"
                  class="absolute -top-2 -right-2 h-6 w-6 rounded-full bg-like-red text-white text-xs font-bold flex items-center justify-center shadow-card hover:bg-red-700"
                  aria-label="Remove photo"
                >
                  ×
                </button>
              </article>
            </div>

            <div class="flex gap-2 flex-wrap">
              <label
                for={@uploads.photos.ref}
                class="px-3 py-2 rounded-button bg-brand-soft text-brand text-sm font-medium hover:bg-brand hover:text-white cursor-pointer"
              >
                Add from gallery
              </label>
              <.live_file_input upload={@uploads.photos} class="sr-only" />

              <label
                for="camera-input"
                class="px-3 py-2 rounded-button bg-brand-soft text-brand text-sm font-medium hover:bg-brand hover:text-white cursor-pointer"
              >
                Take photo
              </label>
              <input
                type="file"
                id="camera-input"
                accept="image/*"
                capture="environment"
                class="sr-only"
                phx-hook="ShareCameraInput"
                data-target={@uploads.photos.ref}
              />
            </div>
            <div class="flex gap-2 mt-3 flex-wrap">
              <article :for={entry <- @uploads.photos.entries} class="w-20 h-20">
                <.live_img_preview entry={entry} class="w-20 h-20 object-cover rounded-input" />
              </article>
            </div>
            <p :for={err <- upload_errors(@uploads.photos)} class="text-red-600 text-xs mt-1">
              {error_to_string(err)}
            </p>
          </section>

          <section class="mb-4">
            <h2 class="text-ink-900 font-medium mb-2">Videos</h2>

            <div class="flex gap-2 flex-wrap">
              <label
                for={@uploads.videos.ref}
                class="px-3 py-2 rounded-button bg-brand-soft text-brand text-sm font-medium hover:bg-brand hover:text-white cursor-pointer"
              >
                Add video from gallery
              </label>
              <.live_file_input upload={@uploads.videos} class="sr-only" />

              <label
                for="video-camera-input"
                class="px-3 py-2 rounded-button bg-brand-soft text-brand text-sm font-medium hover:bg-brand hover:text-white cursor-pointer"
              >
                Take video
              </label>
              <input
                type="file"
                id="video-camera-input"
                accept="video/*"
                capture="environment"
                class="sr-only"
                phx-hook="ShareCameraInput"
                data-target={@uploads.videos.ref}
              />
            </div>

            <ul :if={@uploads.videos.entries != []} class="mt-3 space-y-1">
              <li
                :for={entry <- @uploads.videos.entries}
                class="text-ink-900 text-sm flex items-center justify-between bg-card border border-divider rounded-input px-3 py-2"
              >
                <span class="truncate">{entry.client_name}</span>
                <button
                  type="button"
                  phx-click="cancel_video"
                  phx-value-ref={entry.ref}
                  class="text-like-red text-xs hover:underline ml-2"
                >
                  Remove
                </button>
              </li>
            </ul>
            <p :for={err <- upload_errors(@uploads.videos)} class="text-red-600 text-xs mt-1">
              {error_to_string(err)}
            </p>
          </section>

          <section class="mb-4">
            <h2 class="text-ink-900 font-medium mb-2">Voice note</h2>
            <div
              id="audio-recorder"
              phx-hook="AudioRecorder"
              phx-update="ignore"
              data-upload-target={@uploads.audio_notes.ref}
              class="border border-divider rounded-card p-3 bg-card"
            >
              <p class="text-ink-500 text-xs mb-2">
                Max 60 seconds. Stay in this tab while recording.
              </p>
              <div class="flex items-center gap-3">
                <button
                  type="button"
                  data-role="record-toggle"
                  class="px-3 py-2 rounded-button bg-brand text-white text-sm hover:bg-brand-strong"
                >
                  Record voice note
                </button>
                <span data-role="timer" class="text-ink-500 text-sm">0:00</span>
                <button
                  type="button"
                  data-role="discard"
                  phx-click="discard_audio"
                  class="text-like-red text-sm underline hidden"
                >
                  Discard
                </button>
              </div>
              <audio data-role="preview" controls class="w-full mt-3 hidden"></audio>
              <p data-role="status" class="text-ink-300 text-xs mt-2"></p>
            </div>
            <.live_file_input upload={@uploads.audio_notes} class="sr-only" />
            <p
              :for={err <- upload_errors(@uploads.audio_notes)}
              class="text-red-600 text-xs mt-1"
            >
              {error_to_string(err)}
            </p>
            <p :if={@uploads.audio_notes.entries != []} class="text-ink-500 text-xs mt-2">
              Voice note attached ({@audio_duration_sec}s). Hit Send post to publish.
            </p>
          </section>
        </form>

        <section class="mt-6">
          <h2 class="text-ink-900 font-medium mb-2">Audience</h2>
          <ul class="divide-y divide-divider bg-card rounded-card shadow-card">
            <li class="px-4 py-3 flex items-center justify-between">
              <span class="text-ink-900 font-medium">All residents</span>
              <button
                type="button"
                phx-click="toggle_all_audience"
                class={[
                  "h-6 w-6 rounded-input border-2 border-brand flex items-center justify-center text-brand text-sm font-semibold",
                  audience_indicator_classes(@audience_state)
                ]}
              >
                {audience_indicator(@audience_state)}
              </button>
            </li>
            <li
              :for={r <- @residents}
              class="px-4 py-3 flex items-center justify-between hover:bg-page transition"
            >
              <label class="flex-1 text-ink-900 cursor-pointer">{r.first_name} {r.last_name}</label>
              <button
                type="button"
                phx-click="toggle_audience"
                phx-value-id={r.id}
                aria-pressed={MapSet.member?(@audience_ids, r.id)}
                class={[
                  "h-5 w-5 rounded-input border-2 flex items-center justify-center text-xs font-bold transition",
                  if(MapSet.member?(@audience_ids, r.id),
                    do: "bg-brand border-brand text-white",
                    else: "bg-card border-divider text-transparent hover:border-brand"
                  )
                ]}
              >
                &#x2713;
              </button>
            </li>
          </ul>
        </section>

        <section class="mt-6">
          <h2 class="text-ink-900 font-medium mb-1">Tag in the post header</h2>
          <p class="text-ink-500 text-sm mb-2">
            Tagged residents' names appear publicly under the post. Untag to keep someone in the audience without showing their name.
          </p>

          <ul
            :if={MapSet.size(@audience_ids) > 0}
            class="divide-y divide-divider bg-card rounded-card shadow-card"
          >
            <li
              :for={r <- audience_residents(@residents, @audience_ids)}
              class="px-4 py-3 flex items-center justify-between hover:bg-page transition"
            >
              <span class="text-ink-900">{r.first_name} {r.last_name}</span>
              <button
                type="button"
                phx-click="toggle_tag"
                phx-value-id={r.id}
                class={[
                  "h-5 w-5 rounded-input border-2 flex items-center justify-center text-xs font-bold transition",
                  if(MapSet.member?(@tag_ids, r.id),
                    do: "bg-brand border-brand text-white",
                    else: "bg-card border-divider text-transparent hover:border-brand"
                  )
                ]}
              >
                &#x2713;
              </button>
            </li>
          </ul>

          <p :if={MapSet.size(@audience_ids) == 0} class="text-ink-500 text-sm">
            Add residents to the audience first; tags are chosen from that pool.
          </p>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp audience_residents(residents, audience_ids) do
    Enum.filter(residents, &MapSet.member?(audience_ids, &1.id))
  end

  defp audience_indicator(:all), do: "✓"
  defp audience_indicator(:partial), do: "−"
  defp audience_indicator(:none), do: " "

  defp audience_indicator_classes(:all), do: "bg-brand text-white"
  defp audience_indicator_classes(:partial), do: "bg-brand-soft"
  defp audience_indicator_classes(:none), do: "bg-card"

  defp error_to_string(:too_large), do: "File is too large (max 10 MB)."
  defp error_to_string(:too_many_files), do: "Too many files (max 9)."
  defp error_to_string(:not_accepted), do: "Unsupported file type."
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"
end
