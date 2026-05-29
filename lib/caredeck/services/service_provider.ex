defmodule Caredeck.Services.ServiceProvider do
  use Caredeck.Resource,
    domain: Caredeck.Services,
    default_pub_sub: false,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "service_providers"
    repo Caredeck.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  attributes do
    uuid_primary_key :id
    attribute :facility_id, :uuid, allow_nil?: false, public?: true

    attribute :kind, :atom,
      constraints: [one_of: Caredeck.Services.ProviderKind.all()],
      allow_nil?: false,
      public?: true

    attribute :name, :string, allow_nil?: false, public?: true
    attribute :display_name, :string, public?: true
    attribute :contact_email, :string, public?: true
    attribute :contact_phone, :string, public?: true
    attribute :response_window_label, :string, public?: true
    attribute :response_time_target_hours, :integer, public?: true
    attribute :is_internal, :boolean, default: false, public?: true
    attribute :team_identity_id, :uuid, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :one_per_kind_per_facility, [:facility_id, :kind]
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :team_identity, Caredeck.Accounts.TeamIdentity
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :facility_id,
        :kind,
        :name,
        :display_name,
        :contact_email,
        :contact_phone,
        :response_window_label,
        :response_time_target_hours,
        :is_internal,
        :team_identity_id
      ]
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :name,
        :display_name,
        :contact_email,
        :contact_phone,
        :response_window_label,
        :response_time_target_hours,
        :is_internal,
        :team_identity_id
      ]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                       ^actor(:role_kind) == :care
                   )
    end
  end
end
