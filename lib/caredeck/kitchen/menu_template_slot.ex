defmodule Caredeck.Kitchen.MenuTemplateSlot do
  use Caredeck.Resource,
    domain: Caredeck.Kitchen,
    default_pub_sub: false,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "kitchen_menu_template_slots"
    repo Caredeck.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  attributes do
    uuid_primary_key :id
    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :menu_template_id, :uuid, allow_nil?: false, public?: true

    attribute :day_of_week, :atom,
      constraints: [one_of: ~w(monday tuesday wednesday thursday friday saturday sunday)a],
      allow_nil?: false,
      public?: true

    attribute :category, :atom,
      constraints: [one_of: Caredeck.Kitchen.MealCategory.all()],
      allow_nil?: false,
      public?: true

    attribute :product_id, :uuid, allow_nil?: false, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_slot, [:menu_template_id, :day_of_week, :category]
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :menu_template, Caredeck.Kitchen.MenuTemplate, allow_nil?: false
    belongs_to :product, Caredeck.Kitchen.Product, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      upsert? true
      upsert_identity :unique_slot
      accept [:facility_id, :menu_template_id, :day_of_week, :category, :product_id]
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
