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
