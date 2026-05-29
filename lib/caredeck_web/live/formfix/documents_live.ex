defmodule CaredeckWeb.Formfix.DocumentsLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Formfix.Application, as: AidApplication
  alias Caredeck.Formfix.{RequiredDocuments, SectionKey, UploadedDocument}
  alias Caredeck.Feed.S3
  alias Caredeck.Workers.FormfixDocumentVerifier

  require Ash.Query

  @impl true
  def mount(%{"application_id" => aid, "section_key" => sk}, _session, socket) do
    facility = socket.assigns[:current_facility]
    actor = current_actor(socket)
    section_key = String.to_existing_atom(sk)

    case Ash.get(AidApplication, aid,
           tenant: facility.id,
           actor: actor,
           load: [:resident]
         ) do
      {:ok, application} ->
        slots = RequiredDocuments.for(section_key)
        docs = load_docs(application, section_key)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(Caredeck.PubSub, "formfix:#{application.id}:documents")
        end

        socket =
          Enum.reduce(slots, socket, fn slot, acc ->
            allow_upload(acc, slot.key,
              accept: ~w(.pdf .jpg .jpeg .png),
              max_entries: 1,
              max_file_size: 8_000_000
            )
          end)

        {:ok,
         socket
         |> assign(:page_title, "#{SectionKey.label(section_key)} — Required documents")
         |> assign(:application, application)
         |> assign(:section_key, section_key)
         |> assign(:slots, slots)
         |> assign(:docs_by_slot, group_by_slot(docs))}

      _ ->
        {:ok, push_navigate(socket, to: ~p"/formfix")}
    end
  end

  defp current_actor(socket),
    do: socket.assigns[:current_team] || socket.assigns[:current_user]

  defp load_docs(application, section_key) do
    UploadedDocument
    |> Ash.Query.filter(application_id == ^application.id and section_key == ^section_key)
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.read!(tenant: application.facility_id, authorize?: false)
  end

  defp group_by_slot(docs), do: Enum.group_by(docs, & &1.document_key)

  @impl true
  def handle_event("validate", _, socket), do: {:noreply, socket}

  def handle_event("upload", %{"slot" => slot_key}, socket) do
    slot_atom = String.to_existing_atom(slot_key)
    application = socket.assigns.application

    consume_uploaded_entries(socket, slot_atom, fn %{path: path}, entry ->
      key = S3.generate_key("aid-documents", entry.client_name)
      {:ok, body} = File.read(path)
      {:ok, _} = S3.put_object(key, body, entry.client_type)

      {:ok, doc} =
        UploadedDocument
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: application.facility_id,
            application_id: application.id,
            section_key: socket.assigns.section_key,
            document_key: slot_atom,
            s3_key: key,
            original_filename: entry.client_name,
            bytes: entry.client_size,
            mime_type: entry.client_type
          },
          tenant: application.facility_id,
          authorize?: false
        )
        |> Ash.create(tenant: application.facility_id, authorize?: false)

      %{document_id: doc.id, facility_id: application.facility_id}
      |> FormfixDocumentVerifier.new()
      |> Oban.insert()

      {:ok, doc}
    end)

    {:noreply,
     assign(
       socket,
       :docs_by_slot,
       group_by_slot(load_docs(application, socket.assigns.section_key))
     )}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: event}, socket)
      when event in ["doc_created", "doc_updated"] do
    docs = load_docs(socket.assigns.application, socket.assigns.section_key)
    {:noreply, assign(socket, :docs_by_slot, group_by_slot(docs))}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-3xl px-4 sm:px-6 py-6">
        <.formfix_back_link application_id={@application.id} />

        <header class="mb-6">
          <p class="text-ink-500 text-xs uppercase tracking-wide">
            {SectionKey.label(@section_key)}
          </p>
          <h1 class="text-display-md text-ink-900">Required documents</h1>
        </header>

        <p
          :if={@slots == []}
          class="text-ink-500 text-sm bg-card rounded-card shadow-card p-4"
        >
          No documents required for this section.
        </p>

        <ul :if={@slots != []} class="space-y-4">
          <li :for={slot <- @slots} class="bg-card rounded-card shadow-card p-4">
            <p class="text-ink-900 font-medium">{slot.label}</p>
            <p class="text-ink-500 text-xs mt-1">{slot.legal_note}</p>

            <ul class="mt-3 space-y-1">
              <li
                :for={doc <- Map.get(@docs_by_slot, slot.key, [])}
                class="flex items-center justify-between gap-2 text-sm"
              >
                <span class="text-ink-900 truncate">{doc.original_filename}</span>
                <.verification_pill state={doc.state} />
              </li>
            </ul>

            <form
              phx-change="validate"
              phx-submit="upload"
              phx-value-slot={Atom.to_string(slot.key)}
              class="mt-3 flex items-center gap-2"
            >
              <input type="hidden" name="slot" value={Atom.to_string(slot.key)} />
              <.live_file_input upload={@uploads[slot.key]} class="text-sm" />
              <button
                type="submit"
                class="rounded-button bg-brand text-white text-sm font-medium px-3 py-2 hover:bg-brand-strong"
              >
                Upload
              </button>
            </form>
          </li>
        </ul>

        <.formfix_footer />
      </div>
    </Layouts.app>
    """
  end
end
