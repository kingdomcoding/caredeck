defmodule Caredeck.People.Relative do
  use Caredeck.Resource,
    domain: Caredeck.People,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "relatives"
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
    attribute :display_name, :string, public?: true
    attribute :phone, :string, public?: true
    attribute :avatar_url, :string, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_user_per_facility, [:user_id, :facility_id]
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :user, Caredeck.Accounts.User, allow_nil?: false

    has_many :resident_links, Caredeck.People.RelativeOfResident,
      destination_attribute: :relative_id
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:facility_id, :user_id, :display_name, :phone, :avatar_url]
    end

    update :update do
      primary? true
      accept [:display_name, :phone, :avatar_url]
      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if actor_present()
    end

    policy action_type(:update) do
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action_type([:create, :destroy]) do
      forbid_if always()
    end
  end
end
