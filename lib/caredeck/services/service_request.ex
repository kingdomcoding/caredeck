defmodule Caredeck.Services.ServiceRequest do
  use Caredeck.Resource,
    domain: Caredeck.Services,
    default_pub_sub: false,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "service_requests"
    repo Caredeck.Repo

    references do
      reference :provider, on_delete: :restrict
    end
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  attributes do
    uuid_primary_key :id

    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :provider_id, :uuid, allow_nil?: false, public?: true
    attribute :resident_id, :uuid, public?: true
    attribute :requester_user_id, :uuid, public?: true
    attribute :requester_team_id, :uuid, public?: true

    attribute :subkind, :string, allow_nil?: false, public?: true
    attribute :summary, :string, public?: true
    attribute :payload, :map, default: %{}, public?: true

    attribute :state, :atom,
      constraints: [one_of: [:open, :in_progress, :resolved, :cancelled]],
      default: :open,
      allow_nil?: false,
      public?: true

    attribute :resolved_at, :utc_datetime_usec, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :provider, Caredeck.Services.ServiceProvider, allow_nil?: false
    belongs_to :resident, Caredeck.People.Resident

    belongs_to :requester_user, Caredeck.Accounts.User,
      source_attribute: :requester_user_id,
      define_attribute?: false

    belongs_to :requester_team, Caredeck.Accounts.TeamIdentity,
      source_attribute: :requester_team_id,
      define_attribute?: false

    has_many :messages, Caredeck.Services.ServiceMessage

    has_many :attachments, Caredeck.Feed.Attachment,
      destination_attribute: :service_request_id
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :facility_id,
        :provider_id,
        :resident_id,
        :requester_user_id,
        :requester_team_id,
        :subkind,
        :summary,
        :payload
      ]

      change Caredeck.Services.ValidatePayload
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:summary, :payload]
    end

    update :transition do
      require_atomic? false
      accept [:state]

      change fn changeset, _ ->
        case Ash.Changeset.get_attribute(changeset, :state) do
          :resolved ->
            Ash.Changeset.change_attribute(changeset, :resolved_at, DateTime.utc_now())

          _ ->
            changeset
        end
      end
    end
  end

  pub_sub do
    module CaredeckWeb.Endpoint
    prefix "services"

    publish :create, [:id], event: "request_created"
    publish :transition, [:id], event: "request_updated"
    publish :create, ["inbox", :facility_id], event: "inbox_changed"
    publish :transition, ["inbox", :facility_id], event: "inbox_changed"
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(requester_user_id == ^actor(:id))

      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                       (^actor(:role_kind) == :care or
                          ^actor(:id) == provider.team_identity_id)
                   )

      authorize_if expr(
                     exists(resident.relative_links.relative, user_id == ^actor(:id))
                   )
    end

    policy action(:create) do
      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                       ^actor(:role_kind) == :care
                   )

      authorize_if expr(
                     exists(resident.relative_links.relative, user_id == ^actor(:id))
                   )
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                       (^actor(:role_kind) == :care or
                          ^actor(:id) == provider.team_identity_id)
                   )
    end
  end
end
