defmodule Caredeck.Repo.Migrations.DropUserPasskeys do
  use Ecto.Migration

  def up do
    drop_if_exists index(:user_passkeys, [:credential_id],
                     name: :user_passkeys_unique_credential_index
                   )

    drop_if_exists table(:user_passkeys)
  end

  def down do
    create table(:user_passkeys, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :credential_id, :binary, null: false
      add :public_key, :binary, null: false
      add :sign_count, :bigint, default: 0
      add :aaguid, :string
      add :nickname, :string
      add :last_used_at, :utc_datetime_usec
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create unique_index(:user_passkeys, [:credential_id],
             name: :user_passkeys_unique_credential_index
           )
  end
end
