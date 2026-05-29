defmodule Caredeck.Aid.ApplicationSection do
  use Caredeck.Resource,
    domain: Caredeck.Aid,
    default_pub_sub: false,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "aid_application_sections"
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

    attribute :section_key, :atom,
      constraints: [one_of: Caredeck.Aid.SectionKey.all()],
      allow_nil?: false,
      public?: true

    attribute :position, :integer, allow_nil?: false, public?: true

    attribute :status, :atom,
      constraints: [one_of: [:not_started, :in_progress, :complete, :skipped]],
      default: :not_started,
      allow_nil?: false,
      public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :one_per_section_per_application, [:application_id, :section_key]
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :application, Caredeck.Aid.Application, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      upsert? true
      upsert_identity :one_per_section_per_application
      accept [:facility_id, :application_id, :section_key, :position, :status]
    end

    update :transition do
      require_atomic? false
      accept [:status]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(
                     exists(application,
                       applicant_user_id == ^actor(:id) or
                         (^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                            ^actor(:role_kind) == :care)
                     )
                   )

      authorize_if expr(
                     exists(application.resident.relative_links.relative,
                       user_id == ^actor(:id))
                   )
    end

    policy action_type([:create, :update]) do
      authorize_if expr(
                     exists(application,
                       applicant_user_id == ^actor(:id) or
                         (^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                            ^actor(:role_kind) == :care)
                     )
                   )

      authorize_if expr(
                     exists(application.resident.relative_links.relative,
                       user_id == ^actor(:id))
                   )
    end
  end
end
