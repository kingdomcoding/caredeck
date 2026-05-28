defmodule Caredeck.Kitchen.DayMenuSlot do
  use Caredeck.Resource,
    domain: Caredeck.Kitchen,
    default_pub_sub: false,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "kitchen_day_menu_slots"
    repo Caredeck.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  attributes do
    uuid_primary_key :id
    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :day_menu_id, :uuid, allow_nil?: false, public?: true

    attribute :category, :atom,
      constraints: [one_of: Caredeck.Kitchen.MealCategory.all()],
      allow_nil?: false,
      public?: true

    attribute :product_id, :uuid, allow_nil?: false, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_slot, [:day_menu_id, :category]
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :day_menu, Caredeck.Kitchen.DayMenu, allow_nil?: false
    belongs_to :product, Caredeck.Kitchen.Product, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      upsert? true
      upsert_identity :unique_slot
      accept [:facility_id, :day_menu_id, :category, :product_id]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :destroy]) do
      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                       ^actor(:role_kind) == :kitchen
                   )
    end
  end
end
