defmodule Caredeck.Kitchen.ResidentDietProfile do
  use Caredeck.Resource,
    domain: Caredeck.Kitchen,
    default_pub_sub: false,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "kitchen_resident_diet_profiles"
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
    attribute :allergens, {:array, :string}, default: [], public?: true
    attribute :preferences, {:array, :string}, default: [], public?: true

    attribute :skip_categories, {:array, :atom},
      constraints: [items: [one_of: Caredeck.Kitchen.MealCategory.all()]],
      default: [],
      public?: true

    attribute :notes, :string, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_resident_profile, [:resident_id]
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :resident, Caredeck.People.Resident, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      upsert? true
      upsert_identity :unique_resident_profile
      accept [:facility_id, :resident_id, :allergens, :preferences, :skip_categories, :notes]
    end

    update :update do
      primary? true
      accept [:allergens, :preferences, :skip_categories, :notes]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                       ^actor(:role_kind) in [:kitchen, :care]
                   )

      authorize_if expr(exists(resident.relative_links.relative, user_id == ^actor(:id)))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                       ^actor(:role_kind) in [:kitchen, :care]
                   )

      authorize_if expr(exists(resident.relative_links.relative, user_id == ^actor(:id)))
    end
  end
end
