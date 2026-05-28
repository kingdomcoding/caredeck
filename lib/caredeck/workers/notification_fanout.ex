defmodule Caredeck.Workers.NotificationFanout do
  use Oban.Worker, queue: :fanout, max_attempts: 3

  alias Caredeck.{Accounts, Feed, People}
  alias Caredeck.Notifications.{Notification, Recipients}

  require Ash.Query
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event" => "post_created"} = args}) do
    post_id = args["post_id"]
    facility_id = args["facility_id"]

    {post, recipients} = Recipients.for_post(post_id, facility_id)
    thumbnail = first_attachment_key(post)

    Enum.each(recipients, fn user_id ->
      upsert(%{
        facility_id: facility_id,
        user_id: user_id,
        actor_kind: :team,
        actor_id: post.team_identity_id,
        verb: :posted,
        target_kind: :post,
        target_id: post.id,
        thumbnail_url: thumbnail
      })
    end)

    :ok
  end

  def perform(%Oban.Job{args: %{"event" => "comment_created"} = args}) do
    comment_id = args["comment_id"]
    facility_id = args["facility_id"]

    comment =
      Feed.Comment
      |> Ash.get!(comment_id,
        tenant: facility_id,
        authorize?: false,
        load: [post: [audience: [relative_links: [:relative]], attachments: []]]
      )

    recipients =
      comment.post.audience
      |> Enum.flat_map(& &1.relative_links)
      |> Enum.map(& &1.relative.user_id)
      |> Enum.uniq()
      |> Enum.reject(&(&1 == comment.author_user_id))

    Enum.each(recipients, fn user_id ->
      upsert(%{
        facility_id: facility_id,
        user_id: user_id,
        actor_kind: :user,
        actor_id: comment.author_user_id,
        verb: :commented,
        target_kind: :post,
        target_id: comment.post_id,
        thumbnail_url: first_attachment_key(comment.post)
      })
    end)

    :ok
  end

  def perform(%Oban.Job{args: %{"event" => "reaction_created"} = args}) do
    reaction_id = args["reaction_id"]
    facility_id = args["facility_id"]

    reaction =
      Feed.Reaction
      |> Ash.get!(reaction_id,
        tenant: facility_id,
        authorize?: false,
        load: [post: [audience: [relative_links: [:relative]], attachments: []]]
      )

    recipients =
      reaction.post.audience
      |> Enum.flat_map(& &1.relative_links)
      |> Enum.map(& &1.relative.user_id)
      |> Enum.uniq()
      |> Enum.reject(&(&1 == reaction.user_id))

    Enum.each(recipients, fn user_id ->
      upsert(%{
        facility_id: facility_id,
        user_id: user_id,
        actor_kind: :user,
        actor_id: reaction.user_id,
        verb: :liked,
        target_kind: :post,
        target_id: reaction.post_id,
        thumbnail_url: first_attachment_key(reaction.post)
      })
    end)

    :ok
  end

  def perform(%Oban.Job{args: %{"event" => "invitation_accepted"} = args}) do
    invitation_id = args["invitation_id"]
    facility_id = args["facility_id"]

    invitation =
      People.RelativeInvitation
      |> Ash.get!(invitation_id, tenant: facility_id, authorize?: false)

    joiner_user =
      Accounts.User
      |> Ash.Query.filter(email == ^invitation.email)
      |> Ash.read_one!(authorize?: false)

    new_joiner =
      joiner_user &&
        People.Relative
        |> Ash.Query.filter(facility_id == ^facility_id and user_id == ^joiner_user.id)
        |> Ash.read_one!(tenant: facility_id, authorize?: false)

    recipients = Recipients.for_resident(invitation.resident_id, facility_id)
    joiner_user_id = joiner_user && joiner_user.id

    Enum.each(recipients, fn user_id ->
      if user_id != joiner_user_id do
        upsert(%{
          facility_id: facility_id,
          user_id: user_id,
          actor_kind: :user,
          actor_id: joiner_user_id || invitation.inviter_user_id,
          verb: :joined,
          target_kind: :resident,
          target_id: invitation.resident_id,
          thumbnail_url: new_joiner && new_joiner.avatar_url
        })
      end
    end)

    :ok
  end

  def perform(%Oban.Job{args: args}) do
    Logger.warning("NotificationFanout: unhandled job args=#{inspect(args)}")
    :ok
  end

  defp first_attachment_key(post) do
    case post.attachments do
      [%{s3_key: key} | _] -> key
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp upsert(attrs) do
    Notification
    |> Ash.Changeset.for_create(:create, attrs,
      tenant: attrs.facility_id,
      authorize?: false
    )
    |> Ash.create!(tenant: attrs.facility_id, authorize?: false)
  end
end
