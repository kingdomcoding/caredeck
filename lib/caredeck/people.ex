defmodule Caredeck.People do
  use Ash.Domain, otp_app: :caredeck

  resources do
    resource Caredeck.People.Resident
    resource Caredeck.People.Resident.Version
    resource Caredeck.People.Relative
    resource Caredeck.People.Relative.Version
    resource Caredeck.People.RelativeOfResident
    resource Caredeck.People.RelativeOfResident.Version
    resource Caredeck.People.CaregiverProfile
    resource Caredeck.People.CaregiverProfile.Version
    resource Caredeck.People.RelativeInvitation
    resource Caredeck.People.RelativeInvitation.Version
  end
end
