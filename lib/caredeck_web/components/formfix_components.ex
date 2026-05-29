defmodule CaredeckWeb.FormfixComponents do
  use Phoenix.Component

  def formfix_footer(assigns) do
    ~H"""
    <p class="text-ink-500 text-xs text-center mt-10 mb-4">
      🔒 Your data is safe with us.
    </p>
    """
  end

  attr :application_id, :string, required: true
  attr :label, :string, default: "Back to overview"

  def formfix_back_link(assigns) do
    ~H"""
    <p class="mb-4">
      <a
        href={"/formfix/#{@application_id}/overview"}
        class="text-ink-500 text-sm hover:text-ink-900"
      >
        ← {@label}
      </a>
    </p>
    """
  end

  attr :next_path, :string, required: true
  attr :next_label, :string, required: true

  def next_section_card(assigns) do
    ~H"""
    <aside class="sticky bottom-4 mt-6 bg-card border border-divider rounded-card shadow-card p-4 flex items-center justify-between gap-3">
      <p class="text-ink-500 text-sm">
        Next: <strong class="text-ink-900">{@next_label}</strong>
      </p>
      <a
        href={@next_path}
        class="rounded-button bg-brand text-white text-sm font-medium px-4 py-2 hover:bg-brand-strong"
      >
        Continue →
      </a>
    </aside>
    """
  end

  attr :status, :atom, required: true

  def formfix_status_pill(assigns) do
    ~H"""
    <span class={[
      "text-xs font-medium rounded-full px-2 py-0.5",
      @status == :draft && "bg-page text-ink-500",
      @status == :missing_documents && "bg-yellow-100 text-yellow-700",
      @status == :ready_to_submit && "bg-brand-soft text-brand",
      @status == :submitted && "bg-green-100 text-green-700",
      @status == :approved && "bg-green-200 text-green-900"
    ]}>
      {formfix_status_label(@status)}
    </span>
    """
  end

  attr :status, :atom, required: true

  def section_pill(assigns) do
    ~H"""
    <span class={[
      "text-xs font-medium rounded-full px-2 py-0.5",
      @status == :not_started && "bg-page text-ink-500",
      @status == :in_progress && "bg-yellow-100 text-yellow-700",
      @status == :complete && "bg-green-100 text-green-700",
      @status == :skipped && "bg-ink-100 text-ink-700"
    ]}>
      {section_label(@status)}
    </span>
    """
  end

  attr :summary, :any, required: true

  def section_docs_pill(%{summary: nil} = assigns), do: ~H""

  def section_docs_pill(%{summary: {verified, total}} = assigns) do
    assigns = assign(assigns, verified: verified, total: total, all_done: verified == total)

    ~H"""
    <span class={[
      "text-xs font-medium rounded-full px-2 py-0.5",
      @all_done && "bg-green-100 text-green-700",
      not @all_done && "bg-yellow-100 text-yellow-700"
    ]}>
      {@verified}/{@total} docs
    </span>
    """
  end

  attr :state, :atom, required: true

  def verification_pill(assigns) do
    ~H"""
    <span class={[
      "text-xs font-medium rounded-full px-2 py-0.5",
      @state == :pending && "bg-page text-ink-500",
      @state == :verifying && "bg-yellow-100 text-yellow-700",
      @state == :verified && "bg-green-100 text-green-700",
      @state == :failed && "bg-red-100 text-red-700"
    ]}>
      {verification_label(@state)}
    </span>
    """
  end

  def formfix_status_label(:draft), do: "Draft"
  def formfix_status_label(:missing_documents), do: "Missing documents"
  def formfix_status_label(:ready_to_submit), do: "Ready to submit"
  def formfix_status_label(:submitted), do: "Submitted"
  def formfix_status_label(:approved), do: "Approved"

  def section_label(:not_started), do: "Not started"
  def section_label(:in_progress), do: "In progress"
  def section_label(:complete), do: "Complete"
  def section_label(:skipped), do: "Skipped"

  def verification_label(:pending), do: "Pending"
  def verification_label(:verifying), do: "Verifying…"
  def verification_label(:verified), do: "Successfully verified"
  def verification_label(:failed), do: "Failed"
end
