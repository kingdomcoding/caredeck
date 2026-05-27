defmodule Caredeck.Accounts do
  use Ash.Domain, otp_app: :caredeck, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Caredeck.Accounts.User
    resource Caredeck.Accounts.User.Version
    resource Caredeck.Accounts.Token
  end
end
