defmodule Caredeck.Accounts.TeamIdentity do
  use Ash.Resource,
    otp_app: :caredeck,
    domain: Caredeck.Accounts,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub],
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication, AshPaperTrail.Resource, AshArchival.Resource]

  postgres do
    table "team_identities"
    repo Caredeck.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :handle, :ci_string, allow_nil?: false, public?: true
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true

    attribute :role_kind, :atom,
      constraints: [
        one_of: [:care, :activities, :therapy, :housekeeping, :kitchen, :service, :custom]
      ],
      default: :care,
      public?: true

    attribute :avatar_url, :string, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_handle, [:handle]
  end

  authentication do
    domain Caredeck.Accounts
    session_identifier :jti

    tokens do
      enabled? true
      token_resource Caredeck.Accounts.TeamToken
      signing_secret Caredeck.Accounts.Secrets
      require_token_presence_for_authentication? true
    end

    strategies do
      password :password do
        identity_field :handle
        hash_provider AshAuthentication.BcryptProvider
        sign_in_tokens_enabled? true
        confirmation_required? false

        register_action_accept [:facility_id, :name, :role_kind, :avatar_url]
      end
    end
  end

  paper_trail do
    change_tracking_mode(:changes_only)
    store_action_name?(true)
    ignore_attributes([:hashed_password])
  end

  archive do
    attribute :archived_at
    base_filter?(false)
    exclude_read_actions([:get_with_archived, :list_with_archived])
  end

  actions do
    defaults [:read]
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end
end
