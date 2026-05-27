defmodule Caredeck.People do
  use Ash.Domain, otp_app: :caredeck, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Caredeck.People.Resident
    resource Caredeck.People.Resident.Version
  end
end
