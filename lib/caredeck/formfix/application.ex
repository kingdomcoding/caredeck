defmodule Caredeck.Formfix.Application do
  use Caredeck.Resource,
    domain: Caredeck.Formfix,
    default_pub_sub: false,
    paper_trail: [attributes_as_attributes: [:facility_id]],
    extensions: [AshStateMachine]

  postgres do
    table "formfix_applications"
    repo Caredeck.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  state_machine do
    initial_states([:draft])
    default_initial_state(:draft)

    transitions do
      transition(:mark_missing_documents,
        from: [:draft, :ready_to_submit],
        to: :missing_documents
      )

      transition(:mark_ready_to_submit,
        from: [:draft, :missing_documents],
        to: :ready_to_submit
      )

      transition(:submit, from: :ready_to_submit, to: :submitted)
      transition(:approve, from: :submitted, to: :approved)
    end
  end

  identities do
    identity :one_per_resident, [:facility_id, :resident_id]
  end

  attributes do
    uuid_primary_key :id
    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :resident_id, :uuid, allow_nil?: false, public?: true
    attribute :applicant_user_id, :uuid, public?: true
    attribute :applicant_team_id, :uuid, public?: true

    attribute :state, :atom,
      constraints: [
        one_of: [:draft, :missing_documents, :ready_to_submit, :submitted, :approved]
      ],
      default: :draft,
      allow_nil?: false,
      public?: true

    attribute :submitted_at, :utc_datetime_usec, public?: true
    attribute :decided_at, :utc_datetime_usec, public?: true
    attribute :outcome, :string, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :resident, Caredeck.People.Resident, allow_nil?: false

    belongs_to :applicant_user, Caredeck.Accounts.User,
      source_attribute: :applicant_user_id,
      define_attribute?: false

    belongs_to :applicant_team, Caredeck.Accounts.TeamIdentity,
      source_attribute: :applicant_team_id,
      define_attribute?: false

    has_many :sections, Caredeck.Formfix.ApplicationSection
    has_many :answers, Caredeck.Formfix.SectionAnswer
    has_many :documents, Caredeck.Formfix.UploadedDocument
  end

  aggregates do
    count :total_sections, :sections
    count :sections_done, :sections, filter: expr(status in [:complete, :skipped])
  end

  calculations do
    calculate :progress_percent,
              :integer,
              expr(
                if total_sections == 0 do
                  0
                else
                  sections_done * 100 / total_sections
                end
              )
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:facility_id, :resident_id, :applicant_user_id, :applicant_team_id]
    end

    update :mark_missing_documents do
      require_atomic? false
      change transition_state(:missing_documents)
    end

    update :mark_ready_to_submit do
      require_atomic? false
      change transition_state(:ready_to_submit)
    end

    update :submit do
      require_atomic? false
      change transition_state(:submitted)
      change set_attribute(:submitted_at, &DateTime.utc_now/0)
    end

    update :approve do
      require_atomic? false
      accept [:outcome]
      change transition_state(:approved)
      change set_attribute(:decided_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(applicant_user_id == ^actor(:id))

      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                       ^actor(:role_kind) in [:care, :admin]
                   )

      authorize_if expr(exists(resident.relative_links.relative, user_id == ^actor(:id)))
    end

    policy action(:create) do
      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                       ^actor(:role_kind) == :care
                   )

      authorize_if expr(exists(resident.relative_links.relative, user_id == ^actor(:id)))
    end

    policy action(:submit) do
      authorize_if expr(applicant_user_id == ^actor(:id))

      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                       ^actor(:role_kind) == :care
                   )
    end

    policy action([:approve, :mark_missing_documents, :mark_ready_to_submit]) do
      authorize_if expr(
                     ^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                       ^actor(:role_kind) == :care
                   )
    end
  end
end
