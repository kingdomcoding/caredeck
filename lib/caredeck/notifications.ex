defmodule Caredeck.Notifications do
  use Ash.Domain, otp_app: :caredeck

  resources do
    resource Caredeck.Notifications.Notification
    resource Caredeck.Notifications.Notification.Version
  end
end
