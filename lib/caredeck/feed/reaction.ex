defmodule Caredeck.Feed.Reaction do
  use Caredeck.Resource,
    domain: Caredeck.Feed,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "reactions"
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
    attribute :user_id, :uuid, allow_nil?: false, public?: true

    attribute :kind, :atom,
      constraints: [one_of: [:like, :heart]],
      default: :like,
      allow_nil?: false,
      public?: true

    create_timestamp :inserted_at
  end

  identities do
    identity :one_reaction_per_user_per_post, [:post_id, :user_id]
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :post, Caredeck.Feed.Post, allow_nil?: false
    belongs_to :user, Caredeck.Accounts.User, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:facility_id, :post_id, :user_id, :kind]
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
                     ^actor(:__struct__) == Caredeck.Accounts.User and
                       user_id == ^actor(:id)
                   )
    end
  end
end
