defmodule CaredeckWeb.Aid.OverviewLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Aid.Application, as: AidApplication
  alias Caredeck.Aid.SectionKey

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
        sections_by_key = Map.new(app.sections, &{&1.section_key, &1})

        {:ok,
         socket
         |> assign(:page_title, "Application overview")
         |> assign(:application, app)
         |> assign(:sections_by_key, sections_by_key)}

      _ ->
        {:ok, push_navigate(socket, to: ~p"/aid")}
    end
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
            Long-Term Care Assistance — {@application.resident.first_name} {@application.resident.last_name}
          </h1>

          <div class="mt-3 h-3 w-full bg-page rounded-full overflow-hidden">
            <div class="h-3 bg-brand" style={"width: #{@application.progress_percent}%"}></div>
          </div>
          <div class="flex items-center gap-3 mt-1">
            <p class="text-ink-500 text-xs">{@application.progress_percent}% complete</p>
            <.aid_status_pill status={@application.state} />
          </div>
        </header>

        <div class="grid gap-6 lg:grid-cols-[1fr_280px]">
          <ul class="grid gap-3 sm:grid-cols-2">
            <li :for={key <- SectionKey.base()}>
              <.link
                navigate={~p"/aid/#{@application.id}/section/#{Atom.to_string(key)}"}
                class="block bg-card rounded-card shadow-card p-4 hover:border-brand border border-transparent transition"
              >
                <div class="flex items-center justify-between gap-2 flex-wrap">
                  <p class="text-ink-900 font-medium">{SectionKey.label(key)}</p>
                  <.section_pill status={section_status(@sections_by_key, key)} />
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

        <div class="mt-6">
          <.link
            :if={@application.state == :ready_to_submit}
            navigate={~p"/aid/#{@application.id}/submit"}
            class="inline-block rounded-button bg-brand text-white text-sm font-medium px-4 py-2 hover:bg-brand-strong"
          >
            Go to submit →
          </.link>
        </div>

        <.aid_footer />
      </div>
    </Layouts.app>
    """
  end

  defp section_status(map, key) do
    case Map.get(map, key) do
      nil -> :not_started
      s -> s.status
    end
  end
end
