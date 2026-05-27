defmodule Caredeck.Org.FacilityMembership do
  use Caredeck.Resource, domain: Caredeck.Org

  postgres do
    table "facility_memberships"
    repo Caredeck.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :role, :atom,
      constraints: [one_of: [:admin, :caregiver, :relative, :clinician]],
      allow_nil?: false,
      public?: true

    attribute :source, :atom,
      constraints: [one_of: [:manual, :invited]],
      default: :manual,
      public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :user, Caredeck.Accounts.User
    belongs_to :team_identity, Caredeck.Accounts.TeamIdentity
  end

  identities do
    identity :unique_user_facility, [:user_id, :facility_id], nils_distinct?: true
    identity :unique_team_facility, [:team_identity_id, :facility_id], nils_distinct?: true
  end

  validations do
    validate fn changeset, _context ->
      user_id = Ash.Changeset.get_attribute(changeset, :user_id)
      team_id = Ash.Changeset.get_attribute(changeset, :team_identity_id)

      case {user_id, team_id} do
        {nil, nil} ->
          {:error, field: :user_id, message: "must set user_id or team_identity_id"}

        {_, nil} ->
          :ok

        {nil, _} ->
          :ok

        {_, _} ->
          {:error, field: :user_id, message: "set only one of user_id or team_identity_id"}
      end
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create,
      primary?: true,
      accept: [:facility_id, :user_id, :team_identity_id, :role, :source]
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end
end
