defmodule Caredeck.People.Resident do
  use Caredeck.Resource,
    domain: Caredeck.People,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "residents"
    repo Caredeck.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  attributes do
    uuid_primary_key :id

    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :first_name, :string, allow_nil?: false, public?: true
    attribute :last_name, :string, allow_nil?: false, public?: true
    attribute :date_of_birth, :date, public?: true
    attribute :avatar_url, :string, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:facility_id, :first_name, :last_name, :date_of_birth, :avatar_url]
    end

    update :update do
      primary? true
      accept [:first_name, :last_name, :date_of_birth, :avatar_url]
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end
end
