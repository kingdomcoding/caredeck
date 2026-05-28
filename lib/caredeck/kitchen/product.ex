defmodule Caredeck.Kitchen.Product do
  use Caredeck.Resource,
    domain: Caredeck.Kitchen,
    default_pub_sub: false,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "kitchen_products"
    repo Caredeck.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  attributes do
    uuid_primary_key :id

    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :name, :string, allow_nil?: false, public?: true

    attribute :category, :atom,
      constraints: [one_of: Caredeck.Kitchen.MealCategory.all()],
      allow_nil?: false,
      public?: true

    attribute :allergens, {:array, :string}, default: [], public?: true
    attribute :kcal, :integer, public?: true
    attribute :is_default, :boolean, default: false, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
  end

  identities do
    identity :unique_name_per_facility_per_category, [:facility_id, :category, :name]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:facility_id, :name, :category, :allergens, :kcal, :is_default]
    end

    update :update do
      primary? true
      accept [:name, :allergens, :kcal, :is_default]
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
