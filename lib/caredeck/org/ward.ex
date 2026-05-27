defmodule Caredeck.Org.Ward do
  use Caredeck.Resource, domain: Caredeck.Org

  postgres do
    table "wards"
    repo Caredeck.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]
    create :create, primary?: true, accept: [:name, :facility_id]
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end
end
