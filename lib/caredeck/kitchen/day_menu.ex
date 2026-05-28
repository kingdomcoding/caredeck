defmodule Caredeck.Kitchen.DayMenu do
  use Caredeck.Resource,
    domain: Caredeck.Kitchen,
    default_pub_sub: false,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "kitchen_day_menus"
    repo Caredeck.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  attributes do
    uuid_primary_key :id
    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :date, :date, allow_nil?: false, public?: true
    attribute :notes, :string, public?: true
    attribute :materialised_from_template_id, :uuid, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_facility_date, [:facility_id, :date]
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false

    has_many :slots, Caredeck.Kitchen.DayMenuSlot, destination_attribute: :day_menu_id
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      upsert? true
      upsert_identity :unique_facility_date
      accept [:facility_id, :date, :notes, :materialised_from_template_id]
    end

    update :update do
      primary? true
      accept [:notes]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                       ^actor(:role_kind) == :kitchen
                   )
    end
  end
end
