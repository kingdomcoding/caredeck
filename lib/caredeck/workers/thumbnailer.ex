defmodule Caredeck.Workers.Thumbnailer do
  use Oban.Worker, queue: :thumbnails, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"attachment_id" => id, "facility_id" => facility_id}}) do
    attachment =
      Caredeck.Feed.Attachment
      |> Ash.get!(id, tenant: facility_id, authorize?: false)

    Logger.info(
      "Thumbnailer stub: would generate thumbnail for #{attachment.s3_key} in facility #{facility_id}"
    )

    thumbnail_key = "thumbnails/#{Ecto.UUID.generate()}.jpg"

    attachment
    |> Ash.Changeset.for_update(:update, %{thumbnail_s3_key: thumbnail_key},
      tenant: facility_id,
      authorize?: false
    )
    |> Ash.update!(tenant: facility_id, authorize?: false)

    :ok
  end
end
