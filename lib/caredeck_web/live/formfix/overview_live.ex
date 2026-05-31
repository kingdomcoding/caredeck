defmodule CaredeckWeb.Formfix.OverviewLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Formfix.Application, as: AidApplication
  alias Caredeck.Formfix.{RequiredDocuments, SectionKey, UploadedDocument}

  require Ash.Query

  @impl true
  def mount(%{"application_id" => aid}, _session, socket) do
    facility = socket.assigns[:current_facility]
    actor = current_actor(socket)

    case Ash.get(AidApplication, aid,
           tenant: facility.id,
           actor: actor,
           load: [:resident, :progress_percent, :sections]
         ) do
      {:ok, app} ->
        ordered_sections = Enum.sort_by(app.sections, & &1.position)
        next = Caredeck.Formfix.Applications.next_actionable_section(app)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(Caredeck.PubSub, "formfix:#{app.id}:documents")
        end

        {:ok,
         socket
         |> assign(:page_title, "Formfix overview")
         |> assign(:application, app)
         |> assign(:ordered_sections, ordered_sections)
         |> assign(:docs_summary, docs_summary(app))
         |> assign(:next_actionable, next)
         |> assign(:total_progress, Caredeck.Formfix.Applications.total_progress_percent(app))}

      _ ->
        {:ok, push_navigate(socket, to: ~p"/formfix")}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: event}, socket)
      when event in ["doc_created", "doc_updated"] do
    app = socket.assigns.application

    {:noreply,
     socket
     |> assign(:docs_summary, docs_summary(app))
     |> assign(:total_progress, Caredeck.Formfix.Applications.total_progress_percent(app))}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp docs_summary(application) do
    verified_pairs =
      UploadedDocument
      |> Ash.Query.filter(application_id == ^application.id and state == :verified)
      |> Ash.read!(tenant: application.facility_id, authorize?: false)
      |> Enum.map(&{&1.section_key, &1.document_key})
      |> MapSet.new()

    RequiredDocuments.all_required()
    |> Enum.group_by(fn {section_key, _doc_key} -> section_key end, fn {_, doc_key} -> doc_key end)
    |> Map.new(fn {section_key, doc_keys} ->
      verified =
        Enum.count(doc_keys, fn doc_key ->
          MapSet.member?(verified_pairs, {section_key, doc_key})
        end)

      {section_key, {verified, length(doc_keys)}}
    end)
  end

  defp current_actor(socket),
    do: socket.assigns[:current_team] || socket.assigns[:current_user]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-6xl px-4 sm:px-6 py-6">
        <header class="mb-6">
          <p class="text-ink-500 text-xs uppercase tracking-wide">Your overview</p>
          <h1 class="text-display-md text-ink-900">
            Formfix — {@application.resident.first_name} {@application.resident.last_name}
          </h1>

          <p
            :if={@application.state == :submitted}
            class="text-ink-700 text-sm mt-2"
          >
            Submitted on {format_submitted_at(@application.submitted_at)} · awaiting decision.
          </p>
          <p
            :if={@application.state == :approved}
            class="text-ink-700 text-sm mt-2"
          >
            Approved on {format_submitted_at(@application.decided_at)}.
          </p>

          <div class="mt-3 h-3 w-full bg-page rounded-full overflow-hidden">
            <div class="h-3 bg-brand" style={"width: #{@total_progress}%"}></div>
          </div>
          <div class="flex items-center justify-between gap-3 mt-1 flex-wrap">
            <div class="flex items-center gap-3">
              <p class="text-ink-500 text-xs">{@total_progress}% complete</p>
              <.formfix_status_pill
                :if={@application.state in [:submitted, :approved]}
                status={@application.state}
              />
            </div>

            <.link
              :if={@application.state == :ready_to_submit}
              navigate={~p"/formfix/#{@application.id}/submit"}
              class="rounded-button bg-brand text-white text-sm font-medium px-4 py-2 hover:bg-brand-strong"
            >
              Submit application →
            </.link>

            <.link
              :if={@application.state != :ready_to_submit && @next_actionable}
              navigate={~p"/formfix/#{@application.id}/section/#{Atom.to_string(@next_actionable.section_key)}"}
              class="rounded-button bg-brand text-white text-sm font-medium px-4 py-2 hover:bg-brand-strong"
            >
              {continue_label(@next_actionable)} →
            </.link>
          </div>
        </header>

        <div class="grid gap-6 lg:grid-cols-[1fr_280px]">
          <ul class="grid gap-3 sm:grid-cols-2">
            <li :for={section <- @ordered_sections}>
              <.link
                navigate={~p"/formfix/#{@application.id}/section/#{Atom.to_string(section.section_key)}"}
                class="block bg-card rounded-card shadow-card p-4 hover:border-brand border border-transparent transition"
              >
                <div class="flex items-center justify-between gap-2 flex-wrap">
                  <p class="text-ink-900 font-medium">
                    {SectionKey.label(section.section_key)}
                  </p>
                  <div class="flex items-center gap-2">
                    <.section_pill status={section.status} />
                    <.section_docs_pill summary={Map.get(@docs_summary, section.section_key)} />
                  </div>
                </div>
              </.link>
            </li>
          </ul>

          <aside class="bg-card rounded-card shadow-card p-4 h-fit">
            <p class="text-ink-500 text-xs uppercase tracking-wide mb-2">Support</p>
            <p class="text-ink-900 font-medium">Demo Caseworker</p>
            <p class="text-ink-500 text-sm mt-1">aid@caredeck.example</p>
            <p class="text-ink-500 text-sm">+44 20 0000 0000</p>
            <p class="text-ink-500 text-xs mt-2">Support: Mon–Fri 9 am – 5 pm</p>
          </aside>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp continue_label(%{status: :in_progress, section_key: key}),
    do: "Continue " <> SectionKey.label(key)

  defp continue_label(%{section_key: key}),
    do: "Start " <> SectionKey.label(key)

  defp format_submitted_at(nil), do: "—"

  defp format_submitted_at(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d %b %Y")
  end
end
