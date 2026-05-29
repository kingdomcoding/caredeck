defmodule CaredeckWeb.Services.NewRequestLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Feed
  alias Caredeck.Feed.Attachment
  alias Caredeck.People.{Relative, RelativeOfResident, Resident}
  alias Caredeck.Services.{ProviderKind, ServiceProvider, ServiceRequest}

  require Ash.Query

  @impl true
  def mount(%{"provider_id" => pid}, _session, socket) do
    facility = socket.assigns[:current_facility]
    actor = current_actor(socket)

    cond do
      is_nil(facility) ->
        {:ok, push_navigate(socket, to: ~p"/feed")}

      true ->
        case Ash.get(ServiceProvider, pid, tenant: facility.id, actor: actor) do
          {:ok, provider} ->
            residents = scoped_residents(facility, socket.assigns[:current_user])
            subkind = ProviderKind.default_subkind(provider.kind)

            {:ok,
             socket
             |> assign(:page_title, "New request — #{provider.name}")
             |> assign(:provider, provider)
             |> assign(:residents, residents)
             |> assign(:subkind, Atom.to_string(subkind))
             |> assign(:resident_id, residents |> List.first() |> then(& &1 && &1.id))
             |> assign(:instructions, "")
             |> assign(:medication_name, "")
             |> assign(:question, "")
             |> allow_upload(:prescription,
               accept: ~w(.jpg .jpeg .png .webp),
               max_entries: 1,
               max_file_size: 8_000_000
             )}

          _ ->
            {:ok, push_navigate(socket, to: ~p"/services")}
        end
    end
  end

  defp current_actor(socket),
    do: socket.assigns[:current_team] || socket.assigns[:current_user]

  defp scoped_residents(facility, nil) do
    Resident
    |> Ash.Query.filter(lifecycle_state == :admitted)
    |> Ash.Query.sort(last_name: :asc)
    |> Ash.read!(tenant: facility.id, authorize?: false)
  end

  defp scoped_residents(facility, user) do
    relative_ids =
      Relative
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.read!(tenant: facility.id, authorize?: false)
      |> Enum.map(& &1.id)

    case relative_ids do
      [] ->
        []

      ids ->
        resident_ids =
          RelativeOfResident
          |> Ash.Query.filter(relative_id in ^ids)
          |> Ash.read!(tenant: facility.id, authorize?: false)
          |> Enum.map(& &1.resident_id)
          |> Enum.uniq()

        Resident
        |> Ash.Query.filter(id in ^resident_ids and lifecycle_state == :admitted)
        |> Ash.Query.sort(last_name: :asc)
        |> Ash.read!(tenant: facility.id, authorize?: false)
    end
  end

  @impl true
  def handle_event("pick", %{"subkind" => s}, socket),
    do: {:noreply, assign(socket, :subkind, s)}

  def handle_event("update", params, socket) do
    {:noreply,
     socket
     |> assign(:resident_id, params["resident_id"] || socket.assigns.resident_id)
     |> assign(:instructions, params["instructions"] || socket.assigns.instructions)
     |> assign(
       :medication_name,
       params["medication_name"] || socket.assigns.medication_name
     )
     |> assign(:question, params["question"] || socket.assigns.question)}
  end

  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("submit", params, socket) do
    facility = socket.assigns.current_facility
    actor = current_actor(socket)
    provider = socket.assigns.provider
    attachment_id = maybe_upload_prescription(socket, facility)

    form_assigns = merge_form(socket.assigns, params)

    payload = build_payload(socket.assigns.subkind, form_assigns, attachment_id)
    summary = derive_summary(provider.kind, socket.assigns.subkind, payload)

    requester_user_id = socket.assigns[:current_user] && socket.assigns.current_user.id
    requester_team_id = socket.assigns[:current_team] && socket.assigns.current_team.id

    attrs = %{
      facility_id: facility.id,
      provider_id: provider.id,
      resident_id: form_assigns.resident_id,
      requester_user_id: requester_user_id,
      requester_team_id: requester_team_id,
      subkind: socket.assigns.subkind,
      summary: summary,
      payload: payload
    }

    case ServiceRequest
         |> Ash.Changeset.for_create(:create, attrs, tenant: facility.id, actor: actor)
         |> Ash.create(tenant: facility.id, actor: actor) do
      {:ok, request} ->
        if attachment_id, do: link_attachment(attachment_id, request.id, facility.id)

        {:noreply,
         socket
         |> put_flash(:info, "Request sent.")
         |> push_navigate(to: ~p"/services/requests/#{request.id}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Couldn't send the request.")}
    end
  end

  defp merge_form(assigns, params) do
    %{
      resident_id: params["resident_id"] || assigns.resident_id,
      instructions: params["instructions"] || assigns.instructions,
      medication_name: params["medication_name"] || assigns.medication_name,
      question: params["question"] || assigns.question
    }
  end

  defp build_payload("prescription_upload", assigns, attachment_id) do
    %{
      "subkind" => "prescription_upload",
      "attachment_id" => attachment_id,
      "instructions" => assigns.instructions
    }
  end

  defp build_payload("medication_inquiry", assigns, _attachment_id) do
    %{
      "subkind" => "medication_inquiry",
      "medication_name" => assigns.medication_name,
      "question" => assigns.question
    }
  end

  defp build_payload("general_question", assigns, _attachment_id) do
    %{
      "subkind" => "general_question",
      "question" => assigns.question
    }
  end

  defp maybe_upload_prescription(socket, facility) do
    consumed =
      consume_uploaded_entries(socket, :prescription, fn %{path: path}, entry ->
        key = Feed.S3.generate_key("photos", entry.client_name)
        {:ok, body} = File.read(path)
        {:ok, _} = Feed.S3.put_object(key, body, entry.client_type)

        {:ok, attachment} =
          Attachment
          |> Ash.Changeset.for_create(
            :create,
            %{
              facility_id: facility.id,
              kind: :photo,
              s3_key: key,
              mime_type: entry.client_type,
              bytes: entry.client_size,
              position: 0
            },
            tenant: facility.id,
            authorize?: false
          )
          |> Ash.create(tenant: facility.id, authorize?: false)

        {:ok, attachment.id}
      end)

    List.first(consumed)
  end

  defp link_attachment(att_id, req_id, tenant) do
    Attachment
    |> Ash.get!(att_id, tenant: tenant, authorize?: false)
    |> Ash.Changeset.for_update(:update, %{service_request_id: req_id}, authorize?: false)
    |> Ash.update!(tenant: tenant, authorize?: false)
  end

  defp derive_summary(:pharmacy, "prescription_upload", _),
    do: "Prescription upload"

  defp derive_summary(:pharmacy, "medication_inquiry", %{"medication_name" => m}),
    do: "Inquiry: #{m}"

  defp derive_summary(:pharmacy, "general_question", _),
    do: "Question for pharmacy"

  defp derive_summary(_kind, subkind, _payload), do: subkind

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-md px-4 py-6">
        <h1 class="text-display-sm text-ink-900 mb-4">
          New {ProviderKind.label(@provider.kind) |> String.downcase()} request
        </h1>

        <nav class="flex gap-2 flex-wrap mb-4">
          <button
            :for={sk <- ProviderKind.subkinds_for(@provider.kind)}
            type="button"
            phx-click="pick"
            phx-value-subkind={Atom.to_string(sk)}
            class={[
              "px-3 py-1.5 rounded-input border text-sm",
              @subkind == Atom.to_string(sk) && "bg-brand text-white border-brand",
              @subkind != Atom.to_string(sk) &&
                "bg-card text-ink-900 border-divider hover:border-brand"
            ]}
          >
            {humanize_subkind(sk)}
          </button>
        </nav>

        <form phx-change="update" phx-submit="submit" class="space-y-4">
          <label :if={@residents != []} class="block">
            <span class="text-ink-900 text-sm font-medium">Resident</span>
            <select
              name="resident_id"
              class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
            >
              <option :for={r <- @residents} value={r.id} selected={@resident_id == r.id}>
                {r.first_name} {r.last_name}
              </option>
            </select>
          </label>

          <%= case @subkind do %>
            <% "prescription_upload" -> %>
              <label class="block">
                <span class="text-ink-900 text-sm font-medium">Prescription photo</span>
                <.live_file_input upload={@uploads.prescription} class="mt-1" />
              </label>

              <label class="block">
                <span class="text-ink-900 text-sm font-medium">Instructions</span>
                <textarea
                  name="instructions"
                  rows="3"
                  class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
                >{@instructions}</textarea>
              </label>
            <% "medication_inquiry" -> %>
              <label class="block">
                <span class="text-ink-900 text-sm font-medium">Medication name</span>
                <input
                  name="medication_name"
                  value={@medication_name}
                  class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
                />
              </label>

              <label class="block">
                <span class="text-ink-900 text-sm font-medium">Question</span>
                <textarea
                  name="question"
                  rows="3"
                  class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
                >{@question}</textarea>
              </label>
            <% "general_question" -> %>
              <label class="block">
                <span class="text-ink-900 text-sm font-medium">Question</span>
                <textarea
                  name="question"
                  rows="4"
                  class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
                >{@question}</textarea>
              </label>
            <% _ -> %>
              <p class="text-ink-500 text-sm">
                This subkind is not yet implemented.
              </p>
          <% end %>

          <button
            type="submit"
            class="w-full rounded-button bg-brand text-white px-4 py-2 font-medium"
          >
            Send request
          </button>
        </form>
      </div>
    </Layouts.app>
    """
  end

  defp humanize_subkind(sk) when is_atom(sk),
    do: sk |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
end
