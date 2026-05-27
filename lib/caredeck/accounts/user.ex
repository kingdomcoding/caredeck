defmodule Caredeck.Accounts.User do
  use Ash.Resource,
    otp_app: :caredeck,
    domain: Caredeck.Accounts,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub],
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication, AshPaperTrail.Resource, AshArchival.Resource]

  postgres do
    table "users"
    repo Caredeck.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string, allow_nil?: false, public?: true
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true
    attribute :name, :string, public?: true
    attribute :family_name, :string, public?: true
    attribute :phone, :string, public?: true
    attribute :confirmed_at, :utc_datetime_usec, public?: false

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_email, [:email]
  end

  paper_trail do
    change_tracking_mode :changes_only
    store_action_name? true
    ignore_attributes [:hashed_password]
  end

  archive do
    attribute :archived_at
    base_filter? false
    exclude_read_actions [:get_with_archived, :list_with_archived]
  end

  authentication do
    domain Caredeck.Accounts
    session_identifier :jti

    tokens do
      enabled? true
      token_resource Caredeck.Accounts.Token
      signing_secret Caredeck.Accounts.Secrets
      require_token_presence_for_authentication? true
    end

    strategies do
      password :password do
        identity_field :email
        hash_provider AshAuthentication.BcryptProvider
        sign_in_tokens_enabled? true
        confirmation_required? true

        register_action_accept [:name, :family_name, :phone]

        resettable do
          sender Caredeck.Accounts.UserNotifier
        end
      end
    end

    add_ons do
      confirmation :confirm_new_user do
        monitor_fields [:email]
        confirm_on_create? true
        confirm_on_update? false
        require_interaction? true
        sender Caredeck.Accounts.UserNotifier
      end
    end
  end

  actions do
    defaults [:read]

    update :update_profile do
      accept [:name, :family_name, :phone]
      require_atomic? false
    end
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
