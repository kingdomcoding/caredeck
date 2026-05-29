defmodule Caredeck.Aid do
  use Ash.Domain, otp_app: :caredeck

  resources do
    resource Caredeck.Aid.Application
    resource Caredeck.Aid.Application.Version
    resource Caredeck.Aid.ApplicationSection
    resource Caredeck.Aid.ApplicationSection.Version
  end
end
