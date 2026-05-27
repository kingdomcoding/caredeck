defmodule Caredeck.Accounts.Token do
  use Ash.Resource,
    otp_app: :caredeck,
    domain: Caredeck.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table "tokens"
    repo Caredeck.Repo
  end
end
