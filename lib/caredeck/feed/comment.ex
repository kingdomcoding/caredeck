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
    end

    update :update do
      primary? true
      accept [:body]
      change set_attribute(:edited_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end
end
