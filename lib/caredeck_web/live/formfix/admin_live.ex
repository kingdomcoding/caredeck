defmodule CaredeckWeb.Formfix.AdminLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Formfix.{Application, ApplicationNote, Applications}

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    team = socket.assigns[:current_team]
    fid = team.facility_id

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Caredeck.PubSub, "formfix:#{fid}:admin")
    end

    {:ok,
     socket
     |> assign(:page_title, "Formfix · Admin")
     |> assign(:facility_id, fid)
     |> assign(:applications, load_applications(fid, team))}
  end

  defp load_applications(fid, team) do
    Application
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.load([:resident, :applicant_user, :applicant_team])
    |> Ash.read!(tenant: fid, actor: team)
    |> Enum.map(fn a ->
      Map.merge(a, %{
        total_progress: Applications.total_progress_percent(a),
        notes: load_notes(a, fid, team)
      })
    end)
  end

  defp load_notes(app, fid, team) do
    ApplicationNote
    |> Ash.Query.filter(application_id == ^app.id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(2)
    |> Ash.Query.load(:author_team)
    |> Ash.read!(tenant: fid, actor: team)
  end

  @impl true
  def handle_event("add-note", %{"app_id" => aid, "body" => body}, socket) do
    trimmed = String.trim(body)

    if trimmed == "" do
      {:noreply, socket}
    else
      team = socket.assigns.current_team
      fid = socket.assigns.facility_id

      {:ok, _} =
        ApplicationNote
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: fid,
            application_id: aid,
            author_team_id: team.id,
            body: trimmed
          },
          tenant: fid,
          actor: team
        )
        |> Ash.create(tenant: fid, actor: team)

      Phoenix.PubSub.broadcast(Caredeck.PubSub, "formfix:#{fid}:admin", :reload)
      {:noreply, assign(socket, :applications, load_applications(fid, team))}
    end
  end

  @impl true
  def handle_info(:reload, socket) do
    {:noreply,
     assign(
       socket,
       :applications,
       load_applications(socket.assigns.facility_id, socket.assigns.current_team)
     )}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp relative_name(%{applicant_user: %{name: n}}) when is_binary(n), do: n
  defp relative_name(%{applicant_team: %{name: n}}) when is_binary(n), do: n
  defp relative_name(_), do: "—"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-6xl px-4 sm:px-6 py-6 pb-24 md:pb-6">
        <header class="mb-6">
          <p class="text-ink-500 text-xs uppercase tracking-wide">Admin</p>
          <h1 class="text-display-md text-ink-900">Formfix applications</h1>
          <p class="text-ink-500 text-sm">
            Every Long-Term Care Assistance application in your facility.
          </p>
        </header>

        <p
          :if={@applications == []}
          class="text-ink-500 text-sm text-center py-12 bg-card rounded-card"
        >
          No applications yet.
        </p>

        <div
          :if={@applications != []}
          class="hidden md:block bg-card rounded-card shadow-card overflow-hidden"
        >
          <table class="w-full text-sm">
            <thead class="bg-page text-ink-500 text-xs uppercase tracking-wide">
              <tr>
                <th class="text-left px-4 py-2">Resident</th>
                <th class="text-left px-4 py-2">Relative</th>
                <th class="text-left px-4 py-2">Status</th>
                <th class="text-left px-4 py-2">Progress</th>
                <th class="text-left px-4 py-2">Notes</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-divider">
              <tr :for={a <- @applications}>
                <td class="px-4 py-3 align-top">
                  <.link
                    navigate={~p"/formfix/#{a.id}/overview"}
                    class="text-ink-900 hover:underline"
                  >
                    {a.resident.first_name} {a.resident.last_name}
                  </.link>
                </td>
                <td class="px-4 py-3 text-ink-700 align-top">{relative_name(a)}</td>
                <td class="px-4 py-3 align-top">
                  <.formfix_status_pill status={a.state} />
                </td>
                <td class="px-4 py-3 align-top">
                  <div class="h-2 w-24 bg-page rounded-full overflow-hidden">
                    <div class="h-2 bg-brand" style={"width: #{a.total_progress}%"}></div>
                  </div>
                  <span class="text-ink-500 text-xs">{a.total_progress}%</span>
                </td>
                <td class="px-4 py-3 align-top min-w-[20rem]">
                  <.notes_strip notes={a.notes} />
                  <form phx-submit="add-note" class="mt-2 flex gap-2">
                    <input type="hidden" name="app_id" value={a.id} />
                    <input
                      name="body"
                      placeholder="Add a note…"
                      class="text-xs flex-1 rounded-input border border-divider px-2 py-1"
                    />
                    <button
                      type="submit"
                      phx-disable-with="Saving…"
                      class="text-xs rounded-button bg-brand text-white px-3 py-1 hover:bg-brand-strong"
                    >
                      Save
                    </button>
                  </form>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <ul :if={@applications != []} class="md:hidden space-y-3">
          <li
            :for={a <- @applications}
            class="bg-card rounded-card shadow-card p-4"
          >
            <div class="flex items-start justify-between gap-3">
              <div>
                <.link
                  navigate={~p"/formfix/#{a.id}/overview"}
                  class="text-ink-900 font-medium hover:underline"
                >
                  {a.resident.first_name} {a.resident.last_name}
                </.link>
                <p class="text-ink-500 text-xs">{relative_name(a)}</p>
              </div>
              <.formfix_status_pill status={a.state} />
            </div>
            <div class="mt-3 h-2 w-full bg-page rounded-full overflow-hidden">
              <div class="h-2 bg-brand" style={"width: #{a.total_progress}%"}></div>
            </div>
            <p class="text-ink-500 text-xs mt-1">{a.total_progress}% complete</p>
            <div class="mt-3">
              <.notes_strip notes={a.notes} />
              <form phx-submit="add-note" class="mt-2 flex gap-2">
                <input type="hidden" name="app_id" value={a.id} />
                <input
                  name="body"
                  placeholder="Add a note…"
                  class="text-xs flex-1 rounded-input border border-divider px-2 py-1"
                />
                <button
                  type="submit"
                  phx-disable-with="Saving…"
                  class="text-xs rounded-button bg-brand text-white px-3 py-1 hover:bg-brand-strong"
                >
                  Save
                </button>
              </form>
            </div>
          </li>
        </ul>
      </div>
    </Layouts.app>
    """
  end
end
