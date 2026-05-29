defmodule Caredeck.Formfix.ApplicationNote do
  use Caredeck.Resource,
    domain: Caredeck.Formfix,
    default_pub_sub: false,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "formfix_application_notes"
    repo Caredeck.Repo

    references do
      reference :application, on_delete: :delete
    end
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  attributes do
    uuid_primary_key :id
    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :application_id, :uuid, allow_nil?: false, public?: true
    attribute :author_team_id, :uuid, allow_nil?: false, public?: true

    attribute :body, :string,
      allow_nil?: false,
      public?: true,
      constraints: [max_length: 2000, min_length: 1]

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :application, Caredeck.Formfix.Application, allow_nil?: false

    belongs_to :author_team, Caredeck.Accounts.TeamIdentity,
      source_attribute: :author_team_id,
      define_attribute?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:facility_id, :application_id, :author_team_id, :body]
    end
  end

  policies do
    policy action_type([:read, :create]) do
      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                       ^actor(:role_kind) == :admin
                   )
    end

    policy action_type(:destroy) do
      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                       ^actor(:role_kind) == :admin and
                       author_team_id == ^actor(:id)
                   )
    end
  end
end
