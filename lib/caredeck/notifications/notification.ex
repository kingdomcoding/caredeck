defmodule Caredeck.Notifications.Notification do
  use Caredeck.Resource,
    domain: Caredeck.Notifications,
    default_pub_sub: false,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "notifications"
    repo Caredeck.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  attributes do
    uuid_primary_key :id

    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :user_id, :uuid, allow_nil?: false, public?: true

    attribute :actor_kind, :atom,
      constraints: [one_of: [:user, :team]],
      allow_nil?: false,
      public?: true

    attribute :actor_id, :uuid, allow_nil?: false, public?: true

    attribute :verb, :atom,
      constraints: [one_of: [:posted, :commented, :liked, :joined]],
      allow_nil?: false,
      public?: true

    attribute :target_kind, :atom,
      constraints: [one_of: [:post, :comment, :reaction, :resident]],
      allow_nil?: false,
      public?: true

    attribute :target_id, :uuid, allow_nil?: false, public?: true
    attribute :thumbnail_url, :string, public?: true
    attribute :read_at, :utc_datetime_usec, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_event_per_user,
             [:user_id, :actor_kind, :actor_id, :verb, :target_kind, :target_id]
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :user, Caredeck.Accounts.User, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :facility_id,
        :user_id,
        :actor_kind,
        :actor_id,
        :verb,
        :target_kind,
        :target_id,
        :thumbnail_url
      ]

      upsert? true
      upsert_identity :unique_event_per_user
    end

    update :mark_read do
      accept []
      require_atomic? false
      change set_attribute(:read_at, &DateTime.utc_now/0)
    end

    update :mark_unread do
      accept []
      require_atomic? false
      change set_attribute(:read_at, nil)
    end
  end

  pub_sub do
    module CaredeckWeb.Endpoint
    prefix "user"

    publish :create, [:user_id, "notifications"], event: "notification_created"
    publish :mark_read, [:user_id, "notifications"], event: "notification_updated"
    publish :mark_unread, [:user_id, "notifications"], event: "notification_updated"
    publish :destroy, [:user_id, "notifications"], event: "notification_deleted"
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action(:create) do
      authorize_if always()
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end
end
