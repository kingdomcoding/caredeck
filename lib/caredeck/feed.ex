defmodule Caredeck.Feed do
  use Ash.Domain, otp_app: :caredeck

  resources do
    resource Caredeck.Feed.Post
    resource Caredeck.Feed.Post.Version
    resource Caredeck.Feed.PostAudience
    resource Caredeck.Feed.PostAudience.Version
  end
end
