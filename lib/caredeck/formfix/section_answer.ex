defmodule Caredeck.Formfix.SectionAnswer do
  use Caredeck.Resource,
    domain: Caredeck.Formfix,
    default_pub_sub: false,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "formfix_section_answers"
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
    attribute :section_key, :atom, allow_nil?: false, public?: true
    attribute :field_key, :atom, allow_nil?: false, public?: true

    attribute :value_text, :string, public?: true
    attribute :value_date, :date, public?: true
    attribute :value_bool, :boolean, public?: true
    attribute :value_decimal, :decimal, public?: true
    attribute :value_atom, :atom, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :one_answer_per_field, [:application_id, :section_key, :field_key]
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :application, Caredeck.Formfix.Application, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      upsert? true
      upsert_identity :one_answer_per_field

      accept [
        :facility_id,
        :application_id,
        :section_key,
        :field_key,
        :value_text,
        :value_date,
        :value_bool,
        :value_decimal,
        :value_atom
      ]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(
                     exists(
                       application,
                       applicant_user_id == ^actor(:id) or
                         (^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                            ^actor(:role_kind) in [:care, :admin])
                     )
                   )

      authorize_if expr(
                     exists(
                       application.resident.relative_links.relative,
                       user_id == ^actor(:id)
                     )
                   )
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(
                     exists(
                       application,
                       applicant_user_id == ^actor(:id) or
                         (^actor(:__struct__) == Caredeck.Accounts.TeamIdentity and
                            ^actor(:role_kind) == :care)
                     )
                   )

      authorize_if expr(
                     exists(
                       application.resident.relative_links.relative,
                       user_id == ^actor(:id)
                     )
                   )
    end
  end
end
