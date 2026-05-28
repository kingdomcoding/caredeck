defmodule Caredeck.Accounts.RelativeInvitationNotifier do
  import Swoosh.Email

  alias Caredeck.Mailer

  def send_invite(invitation) do
    url = invite_url(invitation.token)
    facility = Ash.get!(Caredeck.Org.Facility, invitation.facility_id, authorize?: false)

    resident =
      Ash.get!(Caredeck.People.Resident, invitation.resident_id,
        tenant: invitation.facility_id,
        authorize?: false
      )

    inviter = Ash.get!(Caredeck.Accounts.User, invitation.inviter_user_id, authorize?: false)

    new()
    |> to(to_string(invitation.email))
    |> from(Application.fetch_env!(:caredeck, :from_email))
    |> subject(
      "#{inviter_display(inviter)} invited you to keep up with #{resident_display(resident)}"
    )
    |> html_body(html_body(inviter, resident, facility, url))
    |> text_body(text_body(inviter, resident, facility, url))
    |> Mailer.deliver()
  end

  defp invite_url(token) do
    "#{CaredeckWeb.Endpoint.url()}/invitations/#{token}"
  end

  defp resident_display(r), do: "#{r.first_name} #{r.last_name}"
  defp inviter_display(u), do: u.name || to_string(u.email)

  defp html_body(inviter, resident, facility, url) do
    """
    <p>Hi,</p>
    <p>#{inviter_display(inviter)} invited you to join Caredeck for #{resident_display(resident)} at #{facility.name}.</p>
    <p><a href="#{url}">Accept the invitation</a> — the link expires in 7 days.</p>
    """
  end

  defp text_body(inviter, resident, facility, url) do
    """
    Hi,

    #{inviter_display(inviter)} invited you to join Caredeck for #{resident_display(resident)} at #{facility.name}.

    Accept the invitation: #{url}

    The link expires in 7 days.
    """
  end
end
