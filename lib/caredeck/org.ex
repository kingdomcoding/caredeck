defmodule Caredeck.Org do
  use Ash.Domain, otp_app: :caredeck, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Caredeck.Org.District
    resource Caredeck.Org.District.Version
    resource Caredeck.Org.Facility
    resource Caredeck.Org.Facility.Version
    resource Caredeck.Org.Ward
    resource Caredeck.Org.Ward.Version
    resource Caredeck.Org.FacilityMembership
    resource Caredeck.Org.FacilityMembership.Version
  end
end
