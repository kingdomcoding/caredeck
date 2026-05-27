defmodule Caredeck.People.RelativeOfResident do
  use Caredeck.Resource,
    domain: Caredeck.People,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "relatives_of_residents"
    repo Caredeck.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  attributes do
    uuid_primary_key :id

    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :resident_id, :uuid, allow_nil?: false, public?: true
    attribute :relative_id, :uuid, allow_nil?: false, public?: true

    attribute :relationship, :atom,
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
      allow_nil?: false,
      public?: true

    attribute :is_primary_contact, :boolean, default: false, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_link, [:resident_id, :relative_id]
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :resident, Caredeck.People.Resident, allow_nil?: false
    belongs_to :relative, Caredeck.People.Relative, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:facility_id, :resident_id, :relative_id, :relationship, :is_primary_contact]
    end

    update :update do
      primary? true
      accept [:relationship, :is_primary_contact]
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end
end
