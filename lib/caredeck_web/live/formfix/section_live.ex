defmodule CaredeckWeb.Formfix.SectionLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Formfix.Application, as: AidApplication

  alias Caredeck.Formfix.{
    ApplicationSection,
    FieldRationale,
    SectionAnswer,
    SectionKey,
    SectionSchema,
    SectionWriter
  }

  require Ash.Query

  @impl true
  def mount(%{"application_id" => aid, "section_key" => sk}, _session, socket) do
    facility = socket.assigns[:current_facility]
    actor = current_actor(socket)
    section_key = String.to_existing_atom(sk)

    with {:ok, application} <-
           Ash.get(AidApplication, aid,
             tenant: facility.id,
             actor: actor,
             load: [:resident, :sections]
           ),
         {:ok, _section} <- fetch_section(application, section_key) do
      answers = load_answers(application, section_key)
      form_data = build_initial_form(section_key, answers)
      ordered_sections = Enum.sort_by(application.sections, & &1.position)

      if connected?(socket) and Caredeck.Formfix.RequiredDocuments.for(section_key) != [] do
        Phoenix.PubSub.subscribe(Caredeck.PubSub, "formfix:#{application.id}:documents")
      end

      {:ok,
       socket
       |> assign(:page_title, SectionKey.label(section_key))
       |> assign(:application, application)
       |> assign(:section_key, section_key)
       |> assign(:fields, SectionSchema.fields(section_key))
       |> assign(:sub_sections, SectionSchema.sub_sections(section_key))
       |> assign(:ordered_sections, ordered_sections)
       |> assign(:form_data, form_data)
       |> assign(
         :next_key,
         Caredeck.Formfix.Applications.next_section_key(application, section_key)
       )}
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
         |> Ash.Query.filter(application_id == ^application.id and section_key == ^section_key)
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

  defp visible_fields(fields, sub_key, form_data) do
    Enum.filter(fields, fn f -> f.sub == sub_key and show?(f, form_data) end)
  end

  defp show?(field, form_data) do
    case Map.get(field, :show_when) do
      nil -> true
      {key, expected} -> matches?(Map.get(form_data, Atom.to_string(key)), expected)
    end
  end

  defp matches?(value, true), do: value in [true, "true", "on", "1"]
  defp matches?(value, false), do: value in [false, "false", "off", "0", nil, ""]
  defp matches?(value, expected), do: to_string(value) == to_string(expected)

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
    :ok =
      SectionWriter.save_answers!(socket.assigns.application, socket.assigns.section_key, params)

    next =
      case socket.assigns.next_key do
        nil -> ~p"/formfix/#{socket.assigns.application.id}/overview"
        k -> ~p"/formfix/#{socket.assigns.application.id}/section/#{Atom.to_string(k)}"
      end

    {:noreply, push_navigate(socket, to: next)}
  end

  def handle_event("save_draft", params, socket) do
    :ok =
      SectionWriter.save_answers!(socket.assigns.application, socket.assigns.section_key, params)

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
            Formfix walks you through the long-term-care assistance application section by section. It usually takes about
            <strong>30 minutes</strong>
            to complete. You don't have to finish in one sitting — your answers are saved automatically.
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
      </div>
    </Layouts.app>
    """
  end

  defp render_form(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-4xl px-4 sm:px-6 py-6 pb-32 md:pb-28">
        <.formfix_back_link application_id={@application.id} />

        <header class="mb-6">
          <h1 class="text-display-md text-ink-900">{SectionKey.label(@section_key)}</h1>
          <p class="text-ink-500 text-sm">
            For {@application.resident.first_name} {@application.resident.last_name}
          </p>
        </header>

        <form phx-change="change" phx-submit="save" id="section-form" class="space-y-6">
          <section :for={sub <- @sub_sections} class="bg-card rounded-card shadow-card p-4">
            <h2 class="text-ink-900 font-medium mb-3">{sub.label}</h2>

            <div
              :for={f <- visible_fields(@fields, sub.key, @form_data)}
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
        </form>

        <.live_component
          :if={Caredeck.Formfix.RequiredDocuments.for(@section_key) != []}
          module={CaredeckWeb.Formfix.RequiredDocumentsComponent}
          id={"docs-#{@section_key}"}
          application={@application}
          section_key={@section_key}
        />
      </div>

      <div
        role="region"
        aria-label="Section actions"
        class="fixed left-0 right-0 bottom-16 md:bottom-0 z-20 bg-card border-t border-divider shadow-[0_-2px_8px_rgba(0,0,0,0.04)] pb-[env(safe-area-inset-bottom)]"
      >
        <div class="mx-auto max-w-4xl px-4 sm:px-6 py-3 flex items-center justify-between gap-3">
          <p class="text-ink-500 text-xs">
            {section_position(@ordered_sections, @section_key)} of {length(@ordered_sections)}
          </p>
          <div class="flex items-center gap-2">
            <button
              type="button"
              phx-click="skip"
              class="rounded-button border border-divider text-ink-500 text-sm px-3 py-2 hover:border-brand"
            >
              Skip
            </button>
            <button
              type="submit"
              form="section-form"
              class="rounded-button bg-brand text-white text-sm font-medium px-4 py-2 hover:bg-brand-strong"
            >
              Continue →
            </button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp section_position(ordered_sections, current_key) do
    Enum.find_index(ordered_sections, &(&1.section_key == current_key))
    |> case do
      nil -> 1
      idx -> idx + 1
    end
  end

  attr :field, :map, required: true
  attr :value, :any, default: ""

  defp field_input(%{field: %{kind: :string}} = assigns) do
    ~H"""
    <input
      type="text"
      name={Atom.to_string(@field.key)}
      value={@value}
      aria-required={field_required?(@field)}
      class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
    />
    """
  end

  defp field_input(%{field: %{kind: :text}} = assigns) do
    ~H"""
    <textarea
      name={Atom.to_string(@field.key)}
      rows="3"
      aria-required={field_required?(@field)}
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
      aria-required={field_required?(@field)}
      class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
    />
    """
  end

  defp field_input(%{field: %{kind: kind, key: key}} = assigns)
       when kind in [:integer, :decimal] do
    money = Caredeck.Formfix.Money.money?(key)
    monthly = Caredeck.Formfix.Money.monthly?(key)
    assigns = assign(assigns, money: money, monthly: monthly)

    ~H"""
    <div class="mt-1 relative">
      <span
        :if={@money}
        class="absolute left-3 top-1/2 -translate-y-1/2 text-ink-500 pointer-events-none"
      >
        €
      </span>
      <input
        type="number"
        step={if @field.kind == :decimal, do: "0.01", else: "1"}
        name={Atom.to_string(@field.key)}
        value={@value}
        aria-required={field_required?(@field)}
        class={[
          "block w-full rounded-input border border-divider py-2",
          @money && "pl-7 pr-12",
          !@money && "px-3"
        ]}
      />
      <span
        :if={@monthly}
        class="absolute right-3 top-1/2 -translate-y-1/2 text-ink-500 text-xs pointer-events-none"
      >
        /Monat
      </span>
    </div>
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

  defp field_input(%{field: %{kind: :boolean} = field} = assigns) do
    if Map.get(field, :required), do: yes_no_radios(assigns), else: plain_checkbox(assigns)
  end

  defp field_input(%{field: %{kind: {:enum, mod}}} = assigns) when is_atom(mod) do
    assigns = assign(assigns, :mod, mod)

    ~H"""
    <select
      name={Atom.to_string(@field.key)}
      class="mt-1 block w-full rounded-input border border-divider px-3 py-2"
    >
      <option value="" selected={@value in [nil, ""]}>—</option>
      <option
        :for={v <- @mod.all()}
        value={Atom.to_string(v)}
        selected={@value == Atom.to_string(v)}
      >
        {@mod.label(v)}
      </option>
    </select>
    """
  end

  defp field_required?(field) do
    if Map.get(field, :required), do: "true", else: "false"
  end

  defp yes_no_radios(assigns) do
    ~H"""
    <div class="mt-1 space-y-2">
      <.radio
        name={Atom.to_string(@field.key)}
        value="true"
        checked={@value in [true, "true", "on", "1"]}
        label="Yes"
      />
      <.radio
        name={Atom.to_string(@field.key)}
        value="false"
        checked={@value in [false, "false", "off", "0"]}
        label="No"
      />
    </div>
    """
  end

  defp plain_checkbox(assigns) do
    ~H"""
    <div class="mt-1">
      <.checkbox
        name={Atom.to_string(@field.key)}
        checked={@value in [true, "true", "on", "1"]}
      />
    </div>
    """
  end
end
