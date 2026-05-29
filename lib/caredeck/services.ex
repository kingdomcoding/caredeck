defmodule Caredeck.Services do
  use Ash.Domain, otp_app: :caredeck

  resources do
    resource Caredeck.Services.ServiceProvider
    resource Caredeck.Services.ServiceProvider.Version
    resource Caredeck.Services.ServiceRequest
    resource Caredeck.Services.ServiceRequest.Version
    resource Caredeck.Services.ServiceMessage
    resource Caredeck.Services.ServiceMessage.Version
  end
end
