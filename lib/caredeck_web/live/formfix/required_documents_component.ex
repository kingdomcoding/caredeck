defmodule CaredeckWeb.Formfix.RequiredDocumentsComponent do
  use CaredeckWeb, :live_component

  alias Caredeck.Formfix.{RequiredDocuments, UploadedDocument, Verifier}
  alias Caredeck.Feed.S3

  require Ash.Query

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :open, false)}
  end

  @impl true
  def update(%{application: application, section_key: section_key} = assigns, socket) do
    slots = RequiredDocuments.for(section_key)
    initial_open = Map.get(assigns, :initial_open, false)

    socket =
      Enum.reduce(slots, socket, fn slot, acc ->
        if Map.has_key?(acc.assigns, :uploads) and Map.has_key?(acc.assigns.uploads, slot.key) do
          acc
        else
          allow_upload(acc, slot.key,
            accept: ~w(.pdf .jpg .jpeg .png),
            max_entries: 1,
            max_file_size: 8_000_000
          )
        end
      end)

    docs = load_docs(application, section_key)

    {:ok,
     socket
     |> assign(:application, application)
     |> assign(:section_key, section_key)
     |> assign(:slots, slots)
     |> assign(:docs_by_slot, group_by_slot(docs))
     |> assign_new(:open, fn -> initial_open end)
     |> assign(:show_header, Map.get(assigns, :show_header, true))
     |> assign(:variant, Map.get(assigns, :variant, :embedded))}
  end

  @impl true
  def handle_event("toggle", _, socket) do
    {:noreply, assign(socket, :open, not socket.assigns.open)}
  end

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

      Verifier.run_async(doc.id, application.facility_id)

      {:ok, doc}
    end)

    docs = load_docs(application, socket.assigns.section_key)
    {:noreply, assign(socket, :docs_by_slot, group_by_slot(docs))}
  end

  defp load_docs(application, section_key) do
    UploadedDocument
    |> Ash.Query.filter(application_id == ^application.id and section_key == ^section_key)
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.read!(tenant: application.facility_id, authorize?: false)
  end

  defp group_by_slot(docs), do: Enum.group_by(docs, & &1.document_key)

  defp summary(docs_by_slot, slots) do
    total = length(slots)

    verified =
      Enum.count(slots, fn slot ->
        Enum.any?(Map.get(docs_by_slot, slot.key, []), &(&1.state == :verified))
      end)

    {verified, total}
  end

  @impl true
  def render(assigns) do
    {verified, total} = summary(assigns.docs_by_slot, assigns.slots)
    assigns = assign(assigns, verified: verified, total: total, all_verified: verified == total)

    ~H"""
    <section class={[
      @slots == [] && "hidden",
      "rounded-card border border-divider bg-card",
      @variant == :embedded && "mt-6"
    ]}>
      <header
        :if={@show_header}
        class="flex items-center justify-between gap-3 px-4 py-3 cursor-pointer"
        phx-click="toggle"
        phx-target={@myself}
      >
        <div class="flex items-center gap-3">
          <span class="text-ink-900 font-medium">Supporting documents</span>
          <span class={[
            "text-xs font-medium rounded-full px-2 py-0.5",
            @all_verified && "bg-green-100 text-green-700",
            not @all_verified && "bg-yellow-100 text-yellow-700"
          ]}>
            {@verified}/{@total} uploaded
          </span>
        </div>
        <span class="text-ink-500 text-sm">{if @open, do: "Hide", else: "Show"}</span>
      </header>

      <div :if={@open or not @show_header} class="border-t border-divider p-4 space-y-4">
        <p :if={@variant == :embedded} class="text-ink-500 text-xs">
          Upload the documents below. Each one is verified automatically; you can keep filling other sections while verification runs.
        </p>

        <ul class="space-y-4">
          <li :for={slot <- @slots} class="rounded-card border border-divider p-3">
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="text-ink-900 font-medium text-sm">{slot.label}</p>
                <p class="text-ink-500 text-xs mt-1">{slot.legal_note}</p>
              </div>
              <CaredeckWeb.FormfixComponents.verification_pill state={
                slot_state(@docs_by_slot, slot.key)
              } />
            </div>

            <ul
              :if={Map.get(@docs_by_slot, slot.key, []) != []}
              class="mt-3 space-y-1"
            >
              <li
                :for={doc <- Map.get(@docs_by_slot, slot.key, [])}
                class="flex items-center justify-between gap-2 text-xs"
              >
                <span class="text-ink-700 truncate">{doc.original_filename}</span>
                <CaredeckWeb.FormfixComponents.verification_pill state={doc.state} />
              </li>
            </ul>

            <form
              phx-change="validate"
              phx-submit="upload"
              phx-target={@myself}
              phx-value-slot={Atom.to_string(slot.key)}
              class="mt-3 flex items-center gap-2"
            >
              <input type="hidden" name="slot" value={Atom.to_string(slot.key)} />
              <.live_file_input upload={@uploads[slot.key]} class="sr-only" />
              <label
                for={@uploads[slot.key].ref}
                class="rounded-button border border-divider bg-card text-ink-700 text-xs font-medium px-3 py-1.5 hover:border-brand cursor-pointer whitespace-nowrap"
              >
                Choose file
              </label>
              <button
                type="submit"
                phx-disable-with="Uploading…"
                class="rounded-button bg-brand text-white text-xs font-medium px-3 py-1.5 hover:bg-brand-strong disabled:opacity-60"
              >
                Upload
              </button>
            </form>
          </li>
        </ul>

        <p :if={@variant == :embedded} class="text-right">
          <.link
            navigate={
              ~p"/formfix/#{@application.id}/section/#{Atom.to_string(@section_key)}/documents"
            }
            class="text-brand text-xs hover:underline"
          >
            Open in full view →
          </.link>
        </p>
      </div>
    </section>
    """
  end

  defp slot_state(docs_by_slot, slot_key) do
    docs = Map.get(docs_by_slot, slot_key, [])

    cond do
      Enum.any?(docs, &(&1.state == :verified)) -> :verified
      Enum.any?(docs, &(&1.state == :verifying)) -> :verifying
      Enum.any?(docs, &(&1.state == :failed)) -> :failed
      docs != [] -> :pending
      true -> :pending
    end
  end
end
