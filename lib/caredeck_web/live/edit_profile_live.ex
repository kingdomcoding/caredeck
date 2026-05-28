defmodule CaredeckWeb.EditProfileLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Feed.S3
  alias Caredeck.People.{Relative, RelativeOfResident}

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    facility = socket.assigns.current_facility
    user = socket.assigns[:current_user]

    cond do
      is_nil(facility) or is_nil(user) ->
        {:ok, push_navigate(socket, to: ~p"/feed")}

      true ->
        case load_relative(facility, user) do
          nil ->
            {:ok,
             socket
             |> put_flash(:error, "Profile not available yet.")
             |> push_navigate(to: ~p"/feed")}

          relative ->
            {first, family} = split_name(relative.display_name)

            primary_link =
              RelativeOfResident
              |> Ash.Query.filter(relative_id == ^relative.id)
              |> Ash.Query.sort(is_primary_contact: :desc, inserted_at: :asc)
              |> Ash.read!(tenant: facility.id, authorize?: false)
              |> List.first()

            {:ok,
             socket
             |> assign(:relative, relative)
             |> assign(:primary_link, primary_link)
             |> assign(:first_name, first)
             |> assign(:family_name, family)
             |> assign(:phone, relative.phone || "")
             |> assign(
               :relationship,
               (primary_link && to_string(primary_link.relationship)) || ""
             )
             |> assign(:page_title, "Edit profile")
             |> allow_upload(:avatar,
               accept: ~w(.jpg .jpeg .png),
               max_entries: 1,
               max_file_size: 5_000_000
             )}
        end
    end
  end

  defp load_relative(facility, user) do
    case Ash.read_one(
           Relative |> Ash.Query.filter(user_id == ^user.id),
           tenant: facility.id,
           authorize?: false
         ) do
      {:ok, %{} = r} -> r
      _ -> nil
    end
  end

  @impl true
  def handle_event("save", params, socket) do
    facility = socket.assigns.current_facility
    user = socket.assigns.current_user
    relative = socket.assigns.relative

    display_name =
      "#{String.trim(params["first_name"] || "")} #{String.trim(params["family_name"] || "")}"
      |> String.trim()

    avatar_key = consume_avatar(socket)

    update_attrs = %{
      display_name: display_name,
      phone: params["phone"]
    }

    update_attrs =
      if avatar_key, do: Map.put(update_attrs, :avatar_url, avatar_key), else: update_attrs

    {:ok, _} =
      relative
      |> Ash.Changeset.for_update(:update, update_attrs, tenant: facility.id, actor: user)
      |> Ash.update(tenant: facility.id, actor: user)

    if socket.assigns.primary_link && params["relationship"] not in [nil, ""] do
      socket.assigns.primary_link
      |> Ash.Changeset.for_update(
        :update,
        %{relationship: String.to_existing_atom(params["relationship"])},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.update!(tenant: facility.id, authorize?: false)
    end

    {:noreply,
     socket
     |> put_flash(:info, "Profile saved.")
     |> push_navigate(to: ~p"/feed")}
  end

  defp consume_avatar(socket) do
    Application.put_env(:caredeck, :thumbnailer_mode, :off)

    consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
      key = S3.generate_key("avatars", entry.client_name)
      {:ok, body} = File.read(path)
      {:ok, _} = S3.put_object(key, body, entry.client_type)
      {:ok, key}
    end)
    |> List.first()
  end

  defp split_name(nil), do: {"", ""}

  defp split_name(name) do
    case String.split(name, " ", parts: 2) do
      [first, family] -> {first, family}
      [first] -> {first, ""}
      _ -> {"", ""}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-md px-4 py-6">
        <h1 class="text-display-md text-ink-900 mb-4">Edit profile</h1>

        <form phx-submit="save" class="space-y-4">
          <section>
            <h2 class="text-ink-900 font-medium mb-2">Photo</h2>
            <div :if={@relative.avatar_url} class="mb-2">
              <img
                src={"/attachments/" <> @relative.avatar_url}
                class="h-20 w-20 rounded-full object-cover border border-divider"
                alt=""
              />
            </div>
            <.live_file_input
              upload={@uploads.avatar}
              class="block w-full text-sm text-ink-500 file:mr-4 file:py-2 file:px-4 file:rounded-button file:border-0 file:text-sm file:font-medium file:bg-brand-soft file:text-brand hover:file:bg-brand hover:file:text-white file:cursor-pointer"
            />
            <div class="flex gap-2 mt-2">
              <article :for={entry <- @uploads.avatar.entries} class="h-20 w-20">
                <.live_img_preview entry={entry} class="h-20 w-20 object-cover rounded-full" />
              </article>
            </div>
          </section>

          <div class="grid grid-cols-2 gap-3">
            <label class="block">
              <span class="text-ink-900 text-sm font-medium">First name</span>
              <input
                type="text"
                name="first_name"
                value={@first_name}
                class="mt-1 block w-full rounded-input border border-divider px-3 py-2 text-ink-900"
              />
            </label>
            <label class="block">
              <span class="text-ink-900 text-sm font-medium">Family name</span>
              <input
                type="text"
                name="family_name"
                value={@family_name}
                class="mt-1 block w-full rounded-input border border-divider px-3 py-2 text-ink-900"
              />
            </label>
          </div>

          <label class="block">
            <span class="text-ink-900 text-sm font-medium">Phone</span>
            <input
              type="tel"
              name="phone"
              value={@phone}
              class="mt-1 block w-full rounded-input border border-divider px-3 py-2 text-ink-900"
            />
          </label>

          <label class="block">
            <span class="text-ink-900 text-sm font-medium">Relationship to resident</span>
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

          <button type="submit" class="w-full rounded-button bg-brand text-white px-4 py-2">
            Save
          </button>
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
