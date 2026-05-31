defmodule CaredeckWeb.Formfix.DocumentsLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Formfix.Application, as: AidApplication
  alias Caredeck.Formfix.SectionKey

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
        {:ok,
         socket
         |> assign(:page_title, "#{SectionKey.label(section_key)} — Required documents")
         |> assign(:application, application)
         |> assign(:section_key, section_key)}

      _ ->
        {:ok, push_navigate(socket, to: ~p"/formfix")}
    end
  end

  defp current_actor(socket),
    do: socket.assigns[:current_team] || socket.assigns[:current_user]

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: event}, socket)
      when event in ["doc_created", "doc_updated"] do
    send_update(CaredeckWeb.Formfix.RequiredDocumentsComponent,
      id: "docs-#{socket.assigns.section_key}",
      application: socket.assigns.application,
      section_key: socket.assigns.section_key
    )

    {:noreply, socket}
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

        <.live_component
          module={CaredeckWeb.Formfix.RequiredDocumentsComponent}
          id={"docs-#{@section_key}"}
          application={@application}
          section_key={@section_key}
          show_header={false}
          variant={:standalone}
        />

        <p
          :if={Caredeck.Formfix.RequiredDocuments.for(@section_key) == []}
          class="text-ink-500 text-sm bg-card rounded-card shadow-card p-4"
        >
          No documents required for this section.
        </p>
      </div>
    </Layouts.app>
    """
  end
end
