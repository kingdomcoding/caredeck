defmodule Caredeck.Services.ServiceMessage do
  use Caredeck.Resource,
    domain: Caredeck.Services,
    default_pub_sub: false,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "service_messages"
    repo Caredeck.Repo

    references do
      reference :service_request, on_delete: :delete
    end
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  attributes do
    uuid_primary_key :id

    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :service_request_id, :uuid, allow_nil?: false, public?: true
    attribute :author_user_id, :uuid, public?: true
    attribute :author_team_id, :uuid, public?: true
    attribute :body, :string, allow_nil?: false, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :service_request, Caredeck.Services.ServiceRequest, allow_nil?: false

    belongs_to :author_user, Caredeck.Accounts.User,
      source_attribute: :author_user_id,
      define_attribute?: false

    belongs_to :author_team, Caredeck.Accounts.TeamIdentity,
      source_attribute: :author_team_id,
      define_attribute?: false

    has_many :attachments, Caredeck.Feed.Attachment,
      destination_attribute: :service_message_id
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:facility_id, :service_request_id, :author_user_id, :author_team_id, :body]
    end
  end

  pub_sub do
    module CaredeckWeb.Endpoint
    prefix "services"

    publish :create, [:service_request_id], event: "message_created"
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(
                     exists(service_request,
                       requester_user_id == ^actor(:id) or
                         ^actor(:id) == provider.team_identity_id
                     )
                   )

      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                       ^actor(:role_kind) == :care
                   )
    end

    policy action(:create) do
      authorize_if expr(
                     exists(service_request,
                       requester_user_id == ^actor(:id) or
                         ^actor(:id) == provider.team_identity_id
                     )
                   )

      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                       ^actor(:role_kind) == :care
                   )
    end
  end
end
