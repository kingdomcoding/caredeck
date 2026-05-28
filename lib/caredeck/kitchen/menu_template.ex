defmodule Caredeck.Kitchen.MenuTemplate do
  use Caredeck.Resource,
    domain: Caredeck.Kitchen,
    default_pub_sub: false,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "kitchen_menu_templates"
    repo Caredeck.Repo

    identity_wheres_to_sql one_active_per_facility: "is_active = TRUE"
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  attributes do
    uuid_primary_key :id
    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :is_active, :boolean, default: false, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :one_active_per_facility, [:facility_id], where: expr(is_active == true)
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false

    has_many :slots, Caredeck.Kitchen.MenuTemplateSlot,
      destination_attribute: :menu_template_id
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:facility_id, :name, :is_active]
    end

    update :update do
      primary? true
      accept [:name, :is_active]
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
