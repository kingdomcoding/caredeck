defmodule Caredeck.Feed.ResidentTagOnPost do
  use Caredeck.Resource,
    domain: Caredeck.Feed,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "resident_tags_on_posts"
    repo Caredeck.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  attributes do
    uuid_primary_key :id

    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :post_id, :uuid, allow_nil?: false, public?: true
    attribute :resident_id, :uuid, allow_nil?: false, public?: true

    create_timestamp :inserted_at
  end

  identities do
    identity :unique_tag, [:post_id, :resident_id]
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :post, Caredeck.Feed.Post, allow_nil?: false
    belongs_to :resident, Caredeck.People.Resident, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:facility_id, :post_id, :resident_id]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(
                     exists(post.audience.relative_links.relative, user_id == ^actor(:id))
                   )

      authorize_if expr(post.team_identity_id == ^actor(:id))

      authorize_if expr(
                     post.is_internal == false and
                       ^actor(:__struct__) == Caredeck.Accounts.User
                   )
    end

    policy action_type([:create, :destroy]) do
      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                       post.team_identity_id == ^actor(:id)
                   )
    end
  end
end
