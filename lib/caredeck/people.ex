defmodule Caredeck.People do
  use Ash.Domain, otp_app: :caredeck, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Caredeck.People.Resident
    resource Caredeck.People.Resident.Version
    resource Caredeck.People.Relative
    resource Caredeck.People.Relative.Version
    resource Caredeck.People.RelativeOfResident
    resource Caredeck.People.RelativeOfResident.Version
  end
end
