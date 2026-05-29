defmodule Caredeck.Aid.UploadedDocument do
  use Caredeck.Resource,
    domain: Caredeck.Aid,
    default_pub_sub: false,
    paper_trail: [attributes_as_attributes: [:facility_id]],
    extensions: [AshStateMachine]

  postgres do
    table "aid_uploaded_documents"
    repo Caredeck.Repo

    references do
      reference :application, on_delete: :delete
    end
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  state_machine do
    initial_states([:pending])
    default_initial_state(:pending)

    transitions do
      transition(:start_verification, from: :pending, to: :verifying)
      transition(:mark_verified, from: :verifying, to: :verified)
      transition(:mark_failed, from: :verifying, to: :failed)
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :application_id, :uuid, allow_nil?: false, public?: true
    attribute :section_key, :atom, allow_nil?: false, public?: true
    attribute :document_key, :atom, allow_nil?: false, public?: true
    attribute :s3_key, :string, allow_nil?: false, public?: true
    attribute :original_filename, :string, public?: true
    attribute :bytes, :integer, public?: true
    attribute :mime_type, :string, public?: true
    attribute :verified_at, :utc_datetime_usec, public?: true

    attribute :state, :atom,
      constraints: [one_of: [:pending, :verifying, :verified, :failed]],
      default: :pending,
      allow_nil?: false,
      public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :no_duplicate_upload,
             [:application_id, :section_key, :document_key, :s3_key]
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :application, Caredeck.Aid.Application, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :facility_id,
        :application_id,
        :section_key,
        :document_key,
        :s3_key,
        :original_filename,
        :bytes,
        :mime_type
      ]
    end

    update :start_verification do
      require_atomic? false
      change transition_state(:verifying)
    end

    update :mark_verified do
      require_atomic? false
      change transition_state(:verified)
      change set_attribute(:verified_at, &DateTime.utc_now/0)
    end

    update :mark_failed do
      require_atomic? false
      change transition_state(:failed)
    end
  end

  pub_sub do
    module CaredeckWeb.Endpoint
    prefix "aid"

    publish :create, [:application_id, "documents"], event: "doc_created"
    publish :start_verification, [:application_id, "documents"], event: "doc_updated"
    publish :mark_verified, [:application_id, "documents"], event: "doc_updated"
    publish :mark_failed, [:application_id, "documents"], event: "doc_updated"
  end

  policies do
    policy action_type([:read, :create, :update, :destroy]) do
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
