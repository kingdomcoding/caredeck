defmodule Caredeck.Feed.Reaction do
  use Caredeck.Resource,
    domain: Caredeck.Feed,
    default_pub_sub: false,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  import Ecto.Query

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

      change after_action(fn _changeset, reaction, _ctx ->
               %{
                 event: "reaction_created",
                 reaction_id: reaction.id,
                 facility_id: reaction.facility_id
               }
               |> Caredeck.Workers.NotificationFanout.new()
               |> Oban.insert()

               {:ok, reaction}
             end)
    end

    action :toggle, :map do
      argument :facility_id, :uuid, allow_nil?: false
      argument :post_id, :uuid, allow_nil?: false

      argument :kind, :atom,
        constraints: [one_of: [:like, :heart]],
        default: :like

      run fn input, ctx ->
        tenant = input.arguments.facility_id
        actor = ctx.actor

        active =
          from(r in __MODULE__,
            where:
              r.post_id == ^input.arguments.post_id and r.user_id == ^actor.id and
                is_nil(r.archived_at)
          )
          |> Caredeck.Repo.one()

        if active do
          Ash.destroy!(active, tenant: tenant, actor: actor)
          {:ok, %{action: :removed}}
        else
          archived =
            from(r in __MODULE__,
              where:
                r.post_id == ^input.arguments.post_id and r.user_id == ^actor.id and
                  not is_nil(r.archived_at)
            )
            |> Caredeck.Repo.one()

          if archived do
            from(r in __MODULE__, where: r.id == ^archived.id)
            |> Caredeck.Repo.update_all(set: [archived_at: nil])

            {:ok, %{action: :added}}
          else
            Ash.create!(
              __MODULE__,
              %{
                facility_id: tenant,
                post_id: input.arguments.post_id,
                user_id: actor.id,
                kind: input.arguments.kind
              },
              tenant: tenant,
              actor: actor
            )

            {:ok, %{action: :added}}
          end
        end
      end
    end
  end

  pub_sub do
    module CaredeckWeb.Endpoint
    prefix "facility"

    publish :create, [:facility_id, "feed"], event: "reaction_changed"
    publish :destroy, [:facility_id, "feed"], event: "reaction_changed"
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

    policy action(:toggle) do
      authorize_if actor_attribute_equals(:__struct__, Caredeck.Accounts.User)
    end
  end
end
