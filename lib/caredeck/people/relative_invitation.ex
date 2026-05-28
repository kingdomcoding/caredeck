defmodule Caredeck.People.RelativeInvitation do
  use Caredeck.Resource,
    domain: Caredeck.People,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "relative_invitations"
    repo Caredeck.Repo

    identity_wheres_to_sql unique_pending_per_resident_email: "accepted_at IS NULL"
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  attributes do
    uuid_primary_key :id

    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :inviter_user_id, :uuid, allow_nil?: false, public?: true
    attribute :resident_id, :uuid, allow_nil?: false, public?: true
    attribute :email, :ci_string, allow_nil?: false, public?: true

    attribute :suggested_relationship, :atom,
      constraints: [
        one_of: [
          :daughter,
          :son,
          :niece,
          :nephew,
          :granddaughter,
          :grandson,
          :wife,
          :husband,
          :spouse,
          :partner,
          :sibling,
          :legal_guardian,
          :other
        ]
      ],
      public?: true

    attribute :token, :string, sensitive?: true, public?: false
    attribute :expires_at, :utc_datetime_usec, allow_nil?: false, public?: true
    attribute :accepted_at, :utc_datetime_usec, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_pending_per_resident_email, [:resident_id, :email],
      where: expr(is_nil(accepted_at))
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false

    belongs_to :inviter, Caredeck.Accounts.User,
      source_attribute: :inviter_user_id,
      destination_attribute: :id,
      allow_nil?: false

    belongs_to :resident, Caredeck.People.Resident, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:facility_id, :inviter_user_id, :resident_id, :email, :suggested_relationship]

      change set_attribute(:expires_at, &__MODULE__.default_expires_at/0)

      change after_action(fn _changeset, invitation, _ctx ->
               token = sign_token(invitation.id)

               {:ok, signed} =
                 invitation
                 |> Ash.Changeset.for_update(:set_token, %{token: token},
                   tenant: invitation.facility_id,
                   authorize?: false
                 )
                 |> Ash.update(tenant: invitation.facility_id, authorize?: false)

               Caredeck.Accounts.RelativeInvitationNotifier.send_invite(signed)

               {:ok, signed}
             end)
    end

    update :set_token do
      accept [:token]
    end

    update :accept do
      accept []
      require_atomic? false
      change set_attribute(:accepted_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(inviter_user_id == ^actor(:id))
    end

    policy action_type(:create) do
      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.User and
                       inviter_user_id == ^actor(:id)
                   )
    end

    policy action(:accept) do
      authorize_if always()
    end

    policy action(:set_token) do
      authorize_if always()
    end

    policy action_type(:destroy) do
      authorize_if expr(inviter_user_id == ^actor(:id))
    end
  end

  def default_expires_at do
    DateTime.add(DateTime.utc_now(), 7, :day)
  end

  def sign_token(invitation_id) do
    Phoenix.Token.sign(CaredeckWeb.Endpoint, "relative-invitation", invitation_id)
  end

  def verify_token(token) do
    Phoenix.Token.verify(CaredeckWeb.Endpoint, "relative-invitation", token,
      max_age: 7 * 24 * 60 * 60
    )
  end
end
