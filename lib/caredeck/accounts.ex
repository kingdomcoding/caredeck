defmodule Caredeck.Accounts do
  use Ash.Domain, otp_app: :caredeck

  resources do
    resource Caredeck.Accounts.User
    resource Caredeck.Accounts.User.Version
    resource Caredeck.Accounts.Token
    resource Caredeck.Accounts.TeamIdentity
    resource Caredeck.Accounts.TeamIdentity.Version
    resource Caredeck.Accounts.TeamToken
  end
end
