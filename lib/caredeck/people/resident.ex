defmodule Caredeck.People.Resident do
  use Caredeck.Resource,
    domain: Caredeck.People,
    paper_trail: [attributes_as_attributes: [:facility_id]],
    extensions: [AshStateMachine]

  postgres do
    table "residents"
    repo Caredeck.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  attributes do
    uuid_primary_key :id

    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :first_name, :string, allow_nil?: false, public?: true
    attribute :last_name, :string, allow_nil?: false, public?: true
    attribute :birth_name, :string, public?: true
    attribute :date_of_birth, :date, public?: true
    attribute :avatar_url, :string, public?: true

    attribute :lifecycle_state, :atom,
      constraints: [one_of: [:admitted, :discharged, :deceased]],
      default: :admitted,
      allow_nil?: false,
      public?: true

    attribute :admitted_at, :utc_datetime_usec,
      default: &DateTime.utc_now/0,
      public?: true

    attribute :discharged_at, :utc_datetime_usec, public?: true
    attribute :deceased_at, :utc_datetime_usec, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :ward, Caredeck.Org.Ward

    has_many :relative_links, Caredeck.People.RelativeOfResident,
      destination_attribute: :resident_id

    many_to_many :relatives, Caredeck.People.Relative do
      through Caredeck.People.RelativeOfResident
      source_attribute_on_join_resource :resident_id
      destination_attribute_on_join_resource :relative_id
    end

    has_many :post_audiences, Caredeck.Feed.PostAudience,
      destination_attribute: :resident_id
  end

  state_machine do
    state_attribute :lifecycle_state
    initial_states [:admitted]
    default_initial_state :admitted

    transitions do
      transition :discharge, from: :admitted, to: :discharged
      transition :mark_deceased, from: [:admitted, :discharged], to: :deceased
      transition :readmit, from: :discharged, to: :admitted
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [
        :facility_id,
        :ward_id,
        :first_name,
        :last_name,
        :birth_name,
        :date_of_birth,
        :avatar_url
      ]
    end

    update :update do
      primary? true
      accept [:first_name, :last_name, :birth_name, :date_of_birth, :avatar_url, :ward_id]
    end

    update :discharge do
      accept []
      require_atomic? false
      change transition_state(:discharged)
      change set_attribute(:discharged_at, &DateTime.utc_now/0)
    end

    update :mark_deceased do
      accept []
      require_atomic? false
      change transition_state(:deceased)
      change set_attribute(:deceased_at, &DateTime.utc_now/0)
    end

    update :readmit do
      accept []
      require_atomic? false
      change transition_state(:admitted)
      change set_attribute(:discharged_at, nil)
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end
end
