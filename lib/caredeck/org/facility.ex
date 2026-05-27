defmodule Caredeck.Org.Facility do
  use Caredeck.Resource, domain: Caredeck.Org

  postgres do
    table "facilities"
    repo Caredeck.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false, public?: true
    attribute :slug, :ci_string, allow_nil?: false, public?: true
    attribute :timezone, :string, default: "Europe/Berlin", public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_slug, [:slug]
  end

  relationships do
    belongs_to :district, Caredeck.Org.District, allow_nil?: false
    has_many :wards, Caredeck.Org.Ward
    has_many :memberships, Caredeck.Org.FacilityMembership
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :slug, :timezone, :district_id]
    end

    update :update do
      primary? true
      accept [:name, :timezone]
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end
end
