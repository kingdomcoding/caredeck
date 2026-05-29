defmodule CaredeckWeb.Formfix.SectionLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Formfix.Application, as: AidApplication
  alias Caredeck.Formfix.{ApplicationSection, FieldRationale, SectionAnswer, SectionKey, SectionSchema, SectionWriter}

  require Ash.Query

  @impl true
  def mount(%{"application_id" => aid, "section_key" => sk}, _session, socket) do
    facility = socket.assigns[:current_facility]
    actor = current_actor(socket)
    section_key = String.to_existing_atom(sk)

    with {:ok, application} <-
           Ash.get(AidApplication, aid, tenant: facility.id, actor: actor, load: [:resident]),
         {:ok, _section} <- fetch_section(application, section_key) do
      answers = load_answers(application, section_key)
      form_data = build_initial_form(section_key, answers)

      {:ok,
       socket
       |> assign(:page_title, SectionKey.label(section_key))
       |> assign(:application, application)
       |> assign(:section_key, section_key)
       |> assign(:fields, SectionSchema.fields(section_key))
       |> assign(:sub_sections, SectionSchema.sub_sections(section_key))
       |> assign(:form_data, form_data)
       |> assign(:next_key, SectionKey.next_key(section_key))}
    else
      {:error, :section_not_applicable} ->
        {:ok,
         socket
         |> put_flash(:info, "That section isn't applicable for this application.")
         |> push_navigate(to: ~p"/formfix/#{aid}/overview")}

      _ ->
        {:ok, push_navigate(socket, to: ~p"/formfix")}
    end
  end

  defp fetch_section(application, section_key) do
    case ApplicationSection
         |> Ash.Query.filter(
           application_id == ^application.id and section_key == ^section_key
         )
         |> Ash.read_one(tenant: application.facility_id, authorize?: false) do
      {:ok, nil} -> {:error, :section_not_applicable}
      {:ok, section} -> {:ok, section}
      err -> err
    end
  end

  defp current_actor(socket),
    do: socket.assigns[:current_team] || socket.assigns[:current_user]

  defp load_answers(application, section_key) do
    SectionAnswer
    |> Ash.Query.filter(application_id == ^application.id and section_key == ^section_key)
    |> Ash.read!(tenant: application.facility_id, authorize?: false)
    |> Map.new(&{&1.field_key, scalar(&1)})
  end

  defp scalar(%{value_text: v}) when not is_nil(v), do: v
  defp scalar(%{value_date: v}) when not is_nil(v), do: Date.to_iso8601(v)
  defp scalar(%{value_bool: v}) when not is_nil(v), do: v
  defp scalar(%{value_decimal: v}) when not is_nil(v), do: Decimal.to_string(v)
  defp scalar(%{value_atom: v}) when not is_nil(v), do: Atom.to_string(v)
  defp scalar(_), do: ""

  defp build_initial_form(section_key, answers) do
    SectionSchema.fields(section_key)
    |> Map.new(fn f -> {Atom.to_string(f.key), Map.get(answers, f.key, "")} end)
  end

  @impl true
  def handle_event("change", params, socket) do
    {:noreply, assign(socket, :form_data, Map.merge(socket.assigns.form_data, params))}
  end

  def handle_event("save", params, socket) do
    :ok = SectionWriter.save_answers!(socket.assigns.application, socket.assigns.section_key, params)

    next =
      case socket.assigns.next_key do
        nil -> ~p"/formfix/#{socket.assigns.application.id}/overview"
        k -> ~p"/formfix/#{socket.assigns.application.id}/section/#{Atom.to_string(k)}"
      end

    {:noreply, push_navigate(socket, to: next)}
  end

  def handle_event("save_draft", params, socket) do
    :ok = SectionWriter.save_answers!(socket.assigns.application, socket.assigns.section_key, params)
    {:noreply, put_flash(socket, :info, "Draft saved.")}
  end

  def handle_event("begin", _, socket) do
    facility_id = socket.assigns.application.facility_id

    section =
      ApplicationSection
      |> Ash.Query.filter(
        application_id == ^socket.assigns.application.id and
          section_key == ^socket.assigns.section_key
      )
      |> Ash.read_one!(tenant: facility_id, authorize?: false)

    section
    |> Ash.Changeset.for_update(:transition, %{status: :complete},
      tenant: facility_id,
      authorize?: false
    )
    |> Ash.update!(tenant: facility_id, authorize?: false)

    :ok = Caredeck.Formfix.Applications.recompute_status(socket.assigns.application)

    next =
      case socket.assigns.next_key do
        nil -> ~p"/formfix/#{socket.assigns.application.id}/overview"
        k -> ~p"/formfix/#{socket.assigns.application.id}/section/#{Atom.to_string(k)}"
      end

    {:noreply, push_navigate(socket, to: next)}
  end

  def handle_event("skip", _, socket) do
    facility_id = socket.assigns.application.facility_id

    section =
      ApplicationSection
      |> Ash.Query.filter(
        application_id == ^socket.assigns.application.id and
          section_key == ^socket.assigns.section_key
      )
      |> Ash.read_one!(tenant: facility_id, authorize?: false)

    section
    |> Ash.Changeset.for_update(:transition, %{status: :skipped},
      tenant: facility_id,
      authorize?: false
    )
    |> Ash.update!(tenant: facility_id, authorize?: false)

    :ok = Caredeck.Formfix.Applications.recompute_status(socket.assigns.application)

    next =
      case socket.assigns.next_key do
        nil -> ~p"/formfix/#{socket.assigns.application.id}/overview"
        k -> ~p"/formfix/#{socket.assigns.application.id}/section/#{Atom.to_string(k)}"
      end

    {:noreply, push_navigate(socket, to: next)}
  end

  @impl true
  def render(%{section_key: :welcome} = assigns), do: render_welcome(assigns)
  def render(assigns), do: render_form(assigns)

  defp render_welcome(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-3xl px-4 sm:px-6 py-6">
        <.formfix_back_link application_id={@application.id} />

        <header class="mb-6">
          <h1 class="text-display-md text-ink-900">Welcome to Formfix</h1>
          <p class="text-ink-500 text-sm">
            For {@application.resident.first_name} {@application.resident.last_name}
          </p>
        </header>

        <section class="bg-card rounded-card shadow-card p-6 space-y-4">
          <p class="text-ink-900">
            Formfix walks you through the long-term-care assistance application section by section. It usually takes about <strong>30 minutes</strong> to complete. You don't have to finish in one sitting — your answers are saved automatically.
          </p>

          <div>
            <p class="text-ink-900 font-medium mb-2">Here's what we'll cover:</p>
            <ol class="list-decimal pl-5 text-ink-900 text-sm space-y-1">
              <li>Personal details of the person needing care</li>
              <li>Your details as the applicant</li>
              <li>The current care situation</li>
              <li>Income (yours and your partner's, if applicable)</li>
              <li>Assets (yours and your partner's, if applicable)</li>
              <li>Gifts given in the last 10 years</li>
              <li>Monthly expenses</li>
              <li>Disability status (if applicable)</li>
              <li>Foreign-nationality status (if applicable)</li>
            </ol>
          </div>

          <p class="text-ink-500 text-sm">
            You'll be asked to upload a few supporting documents along the way — your ID, a recent pension statement, and so on. The list of what's needed is shown on each section.
          </p>
        </section>

        <div class="mt-6 flex justify-end">
          <button
            type="button"
            phx-click="begin"
            class="rounded-button bg-brand text-white font-medium px-5 py-3 hover:bg-brand-strong"
          >
            Begin →
          </button>
        </div>

        <.formfix_footer />
      </div>
    </Layouts.app>
    """
  end

  defp render_form(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-4xl px-4 sm:px-6 py-6">
        <.formfix_back_link application_id={@application.id} />

        <header class="mb-6">
          <h1 class="text-display-md text-ink-900">{SectionKey.label(@section_key)}</h1>
          <p class="text-ink-500 text-sm">
            For {@application.resident.first_name} {@application.resident.last_name}
          </p>
        </header>

        <form phx-change="change" phx-submit="save" class="space-y-6">
          <section :for={sub <- @sub_sections} class="bg-card rounded-card shadow-card p-4">
            <h2 class="text-ink-900 font-medium mb-3">{sub.label}</h2>

            <div
              :for={f <- Enum.filter(@fields, &(&1.sub == sub.key))}
              class="grid gap-4 lg:grid-cols-[1fr_280px] mb-4"
            >
              <div>
                <label class="block">
                  <span class="text-ink-900 text-sm font-medium">
                    {f.label}<span :if={Map.get(f, :required)} class="text-like-red"> *</span>
                  </span>
                  <.field_input field={f} value={@form_data[Atom.to_string(f.key)]} />
                </label>
              </div>

              <aside
                :if={r = FieldRationale.for(@section_key, f.key)}
                class="text-ink-500 text-xs bg-page rounded-input p-3 self-start"
              >
                {r}
              </aside>
            </div>
          </section>

          <div class="flex justify-end gap-2 sticky bottom-0 bg-card border-t border-divider py-3 px-3">
            <button
              type="button"
              phx-click="skip"
              class="rounded-button bg-card border border-divider text-ink-500 text-sm px-3 py-2 hover:border-brand"
            >
              Skip
            </button>
            <button
              type="submit"
              class="rounded-button bg-brand text-white text-sm font-medium px-4 py-2 hover:bg-brand-strong"
            >
              Continue →
            </button>
          </div>
        </form>

        <div
          :if={Caredeck.Formfix.RequiredDocuments.for(@section_key) != []}
          class="mt-4 text-right"
        >
          <.link
            navigate={~p"/formfix/#{@application.id}/section/#{Atom.to_string(@section_key)}/documents"}
            class="text-brand text-sm hover:underline"
          >
            Required documents →
          </.link>
        </div>

        <.next_section_card
          :if={@next_key}
          next_path={"/formfix/#{@application.id}/section/#{Atom.to_string(@next_key)}"}
          next_label={SectionKey.label(@next_key)}
        />

        <.formfix_footer />
      </div>
    </Layouts.app>
    """
  end

  attr :field, :map, required: true
  attr :value, :any, default: ""

  defp field_input(%{field: %{kind: :string}} = assigns) do
    ~H"""
    <input
      type="text"
      name={Atom.to_string(@field.key)}
      value={@value}
      class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
    />
    """
  end

  defp field_input(%{field: %{kind: :text}} = assigns) do
    ~H"""
    <textarea
      name={Atom.to_string(@field.key)}
      rows="3"
      class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
    >{@value}</textarea>
    """
  end

  defp field_input(%{field: %{kind: :date}} = assigns) do
    ~H"""
    <input
      type="date"
      name={Atom.to_string(@field.key)}
      value={@value}
      class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
    />
    """
  end

  defp field_input(%{field: %{kind: kind}} = assigns) when kind in [:integer, :decimal] do
    ~H"""
    <input
      type="number"
      step={if @field.kind == :decimal, do: "0.01", else: "1"}
      name={Atom.to_string(@field.key)}
      value={@value}
      class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
    />
    """
  end

  defp field_input(%{field: %{kind: {:integer_select, allowed}}} = assigns) do
    assigns = assign(assigns, :allowed, allowed)

    ~H"""
    <select
      name={Atom.to_string(@field.key)}
      class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
    >
      <option value="" selected={@value in [nil, ""]}>—</option>
      <option :for={n <- @allowed} value={n} selected={to_string(@value) == to_string(n)}>
        {n}
      </option>
    </select>
    """
  end

  defp field_input(%{field: %{kind: :boolean}} = assigns) do
    ~H"""
    <div class="mt-1">
      <.checkbox
        name={Atom.to_string(@field.key)}
        checked={@value in [true, "true", "on", "1"]}
        label="Yes"
      />
    </div>
    """
  end

  defp field_input(%{field: %{kind: {:enum, Caredeck.Formfix.MaritalStatus}}} = assigns) do
    ~H"""
    <select
      name={Atom.to_string(@field.key)}
      class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
    >
      <option value="" selected={@value in [nil, ""]}>—</option>
      <option
        :for={v <- Caredeck.Formfix.MaritalStatus.all()}
        value={Atom.to_string(v)}
        selected={@value == Atom.to_string(v)}
      >
        {Caredeck.Formfix.MaritalStatus.label(v)}
      </option>
    </select>
    """
  end

  defp field_input(%{field: %{kind: {:enum, _other}}} = assigns) do
    ~H"""
    <input
      type="text"
      name={Atom.to_string(@field.key)}
      value={@value}
      class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
    />
    """
  end
end
