defmodule Caredeck.Feed.Comment do
  use Caredeck.Resource,
    domain: Caredeck.Feed,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "comments"
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
    attribute :author_user_id, :uuid, allow_nil?: false, public?: true
    attribute :body, :string, allow_nil?: false, public?: true
    attribute :edited_at, :utc_datetime_usec, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :post, Caredeck.Feed.Post, allow_nil?: false

    belongs_to :author, Caredeck.Accounts.User,
      source_attribute: :author_user_id,
      destination_attribute: :id,
      allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:facility_id, :post_id, :author_user_id, :body]

      change after_action(fn _changeset, comment, _ctx ->
               %{
                 event: "comment_created",
                 comment_id: comment.id,
                 facility_id: comment.facility_id
               }
               |> Caredeck.Workers.NotificationFanout.new()
               |> Oban.insert()

               {:ok, comment}
             end)
    end

    update :update do
      primary? true
      accept [:body]
      require_atomic? false
      change set_attribute(:edited_at, &DateTime.utc_now/0)

      validate fn changeset, _ctx ->
        case changeset.data do
          %{inserted_at: %DateTime{} = inserted_at} ->
            age = DateTime.diff(DateTime.utc_now(), inserted_at, :second)

            if age <= 300 do
              :ok
            else
              {:error,
               field: :body,
               message: "Comments can only be edited within 5 minutes of posting."}
            end

          _ ->
            :ok
        end
      end
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

    policy action_type(:create) do
      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.User and
                       author_user_id == ^actor(:id) and
                       (post.is_internal == false or
                          exists(post.audience.relative_links.relative, user_id == ^actor(:id)))
                   )
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(author_user_id == ^actor(:id))
    end
  end
end
