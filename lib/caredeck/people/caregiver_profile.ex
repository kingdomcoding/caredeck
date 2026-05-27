defmodule Caredeck.People.CaregiverProfile do
  use Caredeck.Resource,
    domain: Caredeck.People,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "caregiver_profiles"
    repo Caredeck.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  attributes do
    uuid_primary_key :id

    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :user_id, :uuid, allow_nil?: false, public?: true
    attribute :display_name, :string, allow_nil?: false, public?: true
    attribute :role_label, :string, public?: true
    attribute :avatar_url, :string, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_caregiver_per_facility, [:user_id, :facility_id]
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :user, Caredeck.Accounts.User, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:facility_id, :user_id, :display_name, :role_label, :avatar_url]
    end

    update :update do
      primary? true
      accept [:display_name, :role_label, :avatar_url]
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end
end
