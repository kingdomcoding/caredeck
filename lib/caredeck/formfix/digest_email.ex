defmodule Caredeck.Formfix.DigestEmail do
  import Swoosh.Email

  def build(facility, admins, applications, newly_approved) do
    [primary | rest] = admins
    mailbox = admin_email(facility)

    new()
    |> to({primary.name, mailbox})
    |> cc(Enum.map(rest, &{&1.name, mailbox}))
    |> from(from_address())
    |> subject("Status update: Long-Term Care Assistance applications")
    |> html_body(html_body(facility, primary, applications, newly_approved))
    |> text_body(text_body(facility, primary, applications, newly_approved))
  end

  def admin_email(facility), do: "admin+#{facility.slug}@caredeck.example"

  defp from_address do
    case Application.get_env(:caredeck, :from_email) do
      nil -> {"Caredeck", "no-reply@caredeck.example"}
      addr -> addr
    end
  end

  defp html_body(_facility, primary, applications, newly_approved) do
    rows =
      applications
      |> Enum.map(&render_row/1)
      |> Enum.join("\n")

    celebration =
      newly_approved
      |> Enum.map(&render_celebration/1)
      |> Enum.join("\n")

    """
    <p>Hello #{primary.name},</p>
    <p>Attached is your status overview of all Long-Term Care Assistance applications in your facility:</p>

    <table style="border-collapse: collapse; font-family: -apple-system, sans-serif; font-size: 14px;">
      <thead>
        <tr style="background: #f3f4f6;">
          <th style="text-align: left; padding: 8px;">Resident</th>
          <th style="text-align: left; padding: 8px;">Relative</th>
          <th style="text-align: left; padding: 8px;">Status</th>
          <th style="text-align: left; padding: 8px;">Progress</th>
        </tr>
      </thead>
      <tbody>
        #{rows}
      </tbody>
    </table>

    #{celebration}

    <p style="margin-top: 24px; color: #6b7280; font-size: 12px;">
      This is an automated weekly digest from Caredeck.
    </p>
    """
  end

  defp render_row(app) do
    notes_html =
      app.notes
      |> Enum.map(fn n ->
        ~s(<tr><td colspan="4" style="padding: 4px 8px 4px 24px; color: #4b5563; font-size: 12px;"><strong>Note:</strong> #{escape(n.body)}</td></tr>)
      end)
      |> Enum.join("\n")

    """
    <tr style="border-top: 1px solid #e5e7eb;">
      <td style="padding: 8px;">#{escape(resident_name(app))}</td>
      <td style="padding: 8px;">#{escape(relative_name(app))}</td>
      <td style="padding: 8px;"><span style="#{inline_pill_style(app.state)}">#{status_label(app.state)}</span></td>
      <td style="padding: 8px;">#{app.total_progress}%</td>
    </tr>
    #{notes_html}
    """
  end

  defp render_celebration(app) do
    ~s(<p style="margin-top: 16px; color: #16a34a;">✓ #{escape(resident_name(app))}'s application was successfully approved!</p>)
  end

  defp text_body(_facility, primary, applications, newly_approved) do
    rows =
      applications
      |> Enum.map(fn a ->
        "  · #{resident_name(a)} — #{relative_name(a)} — #{status_label(a.state)} — #{a.total_progress}%" <>
          notes_text(a)
      end)
      |> Enum.join("\n")

    celebration =
      newly_approved
      |> Enum.map(&"\n  ✓ #{resident_name(&1)}'s application was successfully approved!")
      |> Enum.join("")

    """
    Hello #{primary.name},

    Attached is your status overview of all Long-Term Care Assistance applications in your facility:

    #{rows}
    #{celebration}

    This is an automated weekly digest from Caredeck.
    """
  end

  defp notes_text(app) do
    case app.notes do
      [] -> ""
      notes -> "\n" <> Enum.map_join(notes, "\n", &"      Note: #{&1.body}")
    end
  end

  defp resident_name(%{resident: %{first_name: f, last_name: l}}), do: "#{f} #{l}"
  defp resident_name(_), do: "—"

  defp relative_name(%{applicant_user: %{name: n}}) when is_binary(n), do: n
  defp relative_name(%{applicant_team: %{name: n}}) when is_binary(n), do: n
  defp relative_name(_), do: "—"

  def status_label(:draft), do: "Draft"
  def status_label(:missing_documents), do: "Missing Documents"
  def status_label(:ready_to_submit), do: "Ready to Submit"
  def status_label(:submitted), do: "Submitted"
  def status_label(:approved), do: "Approved"

  def inline_pill_style(:draft),
    do: "background:#fef3c7;color:#92400e;padding:2px 6px;border-radius:9999px;"

  def inline_pill_style(:missing_documents),
    do: "background:#ffedd5;color:#9a3412;padding:2px 6px;border-radius:9999px;"

  def inline_pill_style(:ready_to_submit),
    do: "background:#dbeafe;color:#1e40af;padding:2px 6px;border-radius:9999px;"

  def inline_pill_style(:submitted),
    do: "background:#ede9fe;color:#5b21b6;padding:2px 6px;border-radius:9999px;"

  def inline_pill_style(:approved),
    do: "background:#dcfce7;color:#166534;padding:2px 6px;border-radius:9999px;"

  defp escape(nil), do: ""
  defp escape(s), do: s |> to_string() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
