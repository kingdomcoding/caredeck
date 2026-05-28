defmodule Caredeck.Workers.NotificationFanout do
  use Oban.Worker, queue: :fanout, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"post_id" => post_id, "facility_id" => facility_id}}) do
    post =
      Caredeck.Feed.Post
      |> Ash.get!(post_id,
        tenant: facility_id,
        authorize?: false,
        load: [audience: [:relatives]]
      )

    user_ids =
      post.audience
      |> Enum.flat_map(& &1.relatives)
      |> Enum.map(& &1.user_id)
      |> Enum.uniq()

    Logger.info(
      "NotificationFanout: post=#{post.id} facility=#{facility_id} recipients=#{length(user_ids)}"
    )

    :ok
  end
end
