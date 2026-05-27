defmodule Caredeck.Accounts.TeamToken do
  use Ash.Resource,
    otp_app: :caredeck,
    domain: Caredeck.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table "team_tokens"
    repo Caredeck.Repo
  end
end
