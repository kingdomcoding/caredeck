defmodule Caredeck.Kitchen.ResidentMealOrder do
  use Caredeck.Resource,
    domain: Caredeck.Kitchen,
    default_pub_sub: false,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "kitchen_resident_meal_orders"
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
    attribute :date, :date, allow_nil?: false, public?: true

    attribute :category, :atom,
      constraints: [one_of: Caredeck.Kitchen.MealCategory.all()],
      allow_nil?: false,
      public?: true

    attribute :product_id, :uuid, allow_nil?: false, public?: true

    attribute :state, :atom,
      constraints: [one_of: [:ordered, :served, :cancelled]],
      default: :ordered,
      allow_nil?: false,
      public?: true

    attribute :ordered_by_user_id, :uuid, public?: true
    attribute :ordered_by_team_id, :uuid, public?: true
    attribute :notes, :string, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :one_order_per_resident_per_date_per_category,
             [:resident_id, :date, :category]
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :resident, Caredeck.People.Resident, allow_nil?: false
    belongs_to :product, Caredeck.Kitchen.Product, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      upsert? true
      upsert_identity :one_order_per_resident_per_date_per_category

      accept [
        :facility_id,
        :resident_id,
        :date,
        :category,
        :product_id,
        :state,
        :ordered_by_user_id,
        :ordered_by_team_id,
        :notes
      ]
    end

    update :update do
      primary? true
      accept [:product_id, :state, :notes]
      require_atomic? false
    end
  end

  pub_sub do
    module CaredeckWeb.Endpoint
    prefix "facility"

    publish :create, [:facility_id, "kitchen"], event: "order_changed"
    publish :update, [:facility_id, "kitchen"], event: "order_changed"
    publish :destroy, [:facility_id, "kitchen"], event: "order_changed"
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
