defmodule Caredeck.Feed do
  use Ash.Domain, otp_app: :caredeck

  resources do
    resource Caredeck.Feed.Post
    resource Caredeck.Feed.Post.Version
    resource Caredeck.Feed.PostAudience
    resource Caredeck.Feed.PostAudience.Version
    resource Caredeck.Feed.Comment
    resource Caredeck.Feed.Comment.Version
    resource Caredeck.Feed.Reaction
    resource Caredeck.Feed.Reaction.Version
    resource Caredeck.Feed.ResidentTagOnPost
    resource Caredeck.Feed.ResidentTagOnPost.Version
    resource Caredeck.Feed.Attachment
    resource Caredeck.Feed.Attachment.Version
  end
end
