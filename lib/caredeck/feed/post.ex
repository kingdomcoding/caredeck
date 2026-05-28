defmodule Caredeck.Feed.Post do
  use Caredeck.Resource,
    domain: Caredeck.Feed,
    default_pub_sub: false,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "posts"
    repo Caredeck.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  attributes do
    uuid_primary_key :id

    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :team_identity_id, :uuid, allow_nil?: false, public?: true
    attribute :body, :string, allow_nil?: false, public?: true
    attribute :is_internal, :boolean, default: false, public?: true

    attribute :published_at, :utc_datetime_usec,
      default: &DateTime.utc_now/0,
      public?: true

    attribute :edited_at, :utc_datetime_usec, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :team_identity, Caredeck.Accounts.TeamIdentity, allow_nil?: false

    has_many :audience_links, Caredeck.Feed.PostAudience, destination_attribute: :post_id

    many_to_many :audience, Caredeck.People.Resident do
      through Caredeck.Feed.PostAudience
      source_attribute_on_join_resource :post_id
      destination_attribute_on_join_resource :resident_id
    end

    has_many :comments, Caredeck.Feed.Comment, destination_attribute: :post_id
    has_many :reactions, Caredeck.Feed.Reaction, destination_attribute: :post_id

    has_many :attachments, Caredeck.Feed.Attachment,
      destination_attribute: :post_id,
      sort: [position: :asc]

    has_many :resident_tag_links, Caredeck.Feed.ResidentTagOnPost, destination_attribute: :post_id

    many_to_many :resident_tags, Caredeck.People.Resident do
      through Caredeck.Feed.ResidentTagOnPost
      source_attribute_on_join_resource :post_id
      destination_attribute_on_join_resource :resident_id
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:facility_id, :team_identity_id, :body, :is_internal]

      change after_action(fn _changeset, post, _ctx ->
               %{post_id: post.id, facility_id: post.facility_id}
               |> Caredeck.Workers.NotificationFanout.new()
               |> Oban.insert()

               {:ok, post}
             end)
    end

    update :update do
      primary? true
      accept [:body, :is_internal]
      change set_attribute(:edited_at, &DateTime.utc_now/0)
    end
  end

  pub_sub do
    module CaredeckWeb.Endpoint
    prefix "facility"

    publish :create, [:facility_id, "feed"], event: "post_created"
    publish :update, [:facility_id, "feed"], event: "post_updated"
    publish :destroy, [:facility_id, "feed"], event: "post_deleted"
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:team_identity])
      authorize_if expr(exists(audience.relative_links.relative, user_id == ^actor(:id)))

      authorize_if expr(
                     is_internal == false and
                       ^actor(:__struct__) == Caredeck.Accounts.User
                   )
    end

    policy action_type(:create) do
      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                       team_identity_id == ^actor(:id) and
                       facility_id == ^actor(:facility_id)
                   )
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(team_identity_id == ^actor(:id))
    end
  end
end
