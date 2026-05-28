defmodule Caredeck.Accounts.UserPasskey do
  use Ash.Resource,
    otp_app: :caredeck,
    domain: Caredeck.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "user_passkeys"
    repo Caredeck.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :user_id, :uuid, allow_nil?: false, public?: true
    attribute :credential_id, :binary, allow_nil?: false, public?: true
    attribute :public_key, :binary, allow_nil?: false, sensitive?: true, public?: false
    attribute :sign_count, :integer, default: 0, public?: true
    attribute :aaguid, :string, public?: true
    attribute :nickname, :string, public?: true
    attribute :last_used_at, :utc_datetime_usec, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_credential, [:credential_id]
  end

  relationships do
    belongs_to :user, Caredeck.Accounts.User, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :user_id,
        :credential_id,
        :public_key,
        :sign_count,
        :aaguid,
        :nickname
      ]
    end

    update :record_use do
      accept [:sign_count]
      require_atomic? false
      change set_attribute(:last_used_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if AshAuthentication.Checks.AshAuthenticationInteraction
    end

    policy action(:create) do
      authorize_if AshAuthentication.Checks.AshAuthenticationInteraction
    end

    policy action(:record_use) do
      authorize_if AshAuthentication.Checks.AshAuthenticationInteraction
    end

    policy action_type(:destroy) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end
end
