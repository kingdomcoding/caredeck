defmodule CaredeckWeb.Formfix.SubmitLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Formfix.Application, as: AidApplication
  alias Caredeck.Formfix.{SectionAnswer, SectionKey, SectionSchema}

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
        answers_by_section = load_answers(app)
        ordered_keys = app.sections |> Enum.sort_by(& &1.position) |> Enum.map(& &1.section_key)

        {:ok,
         socket
         |> assign(:page_title, "Review and submit")
         |> assign(:application, app)
         |> assign(:answers_by_section, answers_by_section)
         |> assign(:ordered_keys, ordered_keys)
         |> assign(:total_progress, Caredeck.Formfix.Applications.total_progress_percent(app))}

      _ ->
        {:ok, push_navigate(socket, to: ~p"/formfix")}
    end
  end

  defp current_actor(socket),
    do: socket.assigns[:current_team] || socket.assigns[:current_user]

  defp load_answers(application) do
    SectionAnswer
    |> Ash.Query.filter(application_id == ^application.id)
    |> Ash.read!(tenant: application.facility_id, authorize?: false)
    |> Enum.group_by(& &1.section_key)
  end

  @impl true
  def handle_event("submit", _, socket) do
    app = socket.assigns.application
    actor = current_actor(socket)

    case app
         |> Ash.Changeset.for_update(:submit, %{}, tenant: app.facility_id, actor: actor)
         |> Ash.update(tenant: app.facility_id, actor: actor) do
      {:ok, updated} ->
        %{
          "event" => "application_submitted",
          "application_id" => updated.id,
          "facility_id" => updated.facility_id
        }
        |> Caredeck.Workers.NotificationFanout.new()
        |> Oban.insert()

        {:noreply,
         socket
         |> put_flash(:info, "Application submitted.")
         |> push_navigate(to: ~p"/formfix/#{updated.id}/overview")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Cannot submit yet.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-3xl px-4 sm:px-6 py-6">
        <.formfix_back_link application_id={@application.id} />

        <header class="mb-6">
          <h1 class="text-display-md text-ink-900">{header_title(@application.state)}</h1>
          <p class="text-ink-500 text-sm">
            For {@application.resident.first_name} {@application.resident.last_name}
          </p>
          <div class="mt-3 flex items-center gap-3">
            <p class="text-ink-500 text-xs">{@total_progress}% complete</p>
            <.formfix_status_pill
              :if={@application.state in [:submitted, :approved]}
              status={@application.state}
            />
          </div>
        </header>

        <div
          :if={@application.state == :submitted}
          class="bg-purple-50 border border-purple-200 rounded-card p-4 mb-6"
        >
          <p class="text-purple-900 font-medium">
            Submitted on {format_submitted_at(@application.submitted_at)}
          </p>
          <p class="text-purple-800 text-sm mt-1">
            Awaiting decision. We'll notify you when it's reviewed.
          </p>
        </div>

        <div
          :if={@application.state == :approved}
          class="bg-green-50 border border-green-200 rounded-card p-4 mb-6"
        >
          <p class="text-green-900 font-medium">
            Approved on {format_submitted_at(@application.decided_at)}
          </p>
          <p :if={@application.outcome} class="text-green-800 text-sm mt-1">
            {@application.outcome}
          </p>
        </div>

        <ul class="space-y-4">
          <li :for={key <- @ordered_keys} class="bg-card rounded-card shadow-card p-4">
            <p class="text-ink-900 font-medium mb-2">{SectionKey.label(key)}</p>
            <p
              :if={Map.get(@answers_by_section, key, []) == []}
              class="text-ink-500 text-xs"
            >
              No answers provided.
            </p>
            <dl
              :if={Map.get(@answers_by_section, key, []) != []}
              class="grid gap-1 text-sm"
            >
              <div
                :for={a <- Map.get(@answers_by_section, key, [])}
                class="grid grid-cols-[200px_1fr] gap-2"
              >
                <dt class="text-ink-500">{field_label(key, a.field_key)}</dt>
                <dd class="text-ink-900">{render_value(a)}</dd>
              </div>
            </dl>
          </li>
        </ul>

        <button
          :if={@application.state not in [:submitted, :approved]}
          type="button"
          phx-click="submit"
          disabled={@application.state != :ready_to_submit}
          class={[
            "mt-6 w-full rounded-button text-white px-4 py-3 font-medium",
            @application.state == :ready_to_submit && "bg-brand hover:bg-brand-strong",
            @application.state != :ready_to_submit && "bg-ink-300 cursor-not-allowed"
          ]}
        >
          Submit application
        </button>

        <p
          :if={@application.state not in [:ready_to_submit, :submitted, :approved]}
          class="text-ink-500 text-xs text-center mt-2"
        >
          Please complete all sections and upload all required documents before submitting.
        </p>
      </div>
    </Layouts.app>
    """
  end

  defp field_label(section_key, field_key) do
    case Enum.find(SectionSchema.fields(section_key), &(&1.key == field_key)) do
      nil -> Atom.to_string(field_key)
      f -> f.label
    end
  end

  defp render_value(%{value_text: v}) when not is_nil(v), do: v
  defp render_value(%{value_date: v}) when not is_nil(v), do: Date.to_string(v)
  defp render_value(%{value_bool: true}), do: "Yes"
  defp render_value(%{value_bool: false}), do: "No"
  defp render_value(%{value_decimal: v}) when not is_nil(v), do: Decimal.to_string(v)
  defp render_value(%{value_atom: v}) when not is_nil(v), do: Atom.to_string(v)
  defp render_value(_), do: "—"

  defp format_submitted_at(nil), do: "—"

  defp format_submitted_at(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d %b %Y at %H:%M UTC")
  end

  defp header_title(:submitted), do: "Submitted"
  defp header_title(:approved), do: "Approved"
  defp header_title(_), do: "Review and submit"
end
