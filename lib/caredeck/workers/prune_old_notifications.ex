defmodule Caredeck.Workers.PruneOldNotifications do
  use Oban.Worker, queue: :default, max_attempts: 3

  require Ash.Query
  require Logger

  @retention_days 90

  @impl Oban.Worker
  def perform(_job) do
    cutoff = DateTime.add(DateTime.utc_now(), -@retention_days, :day)

    facilities = Caredeck.Org.Facility |> Ash.read!(authorize?: false)

    deleted =
      Enum.reduce(facilities, 0, fn facility, acc ->
        stale =
          Caredeck.Notifications.Notification
          |> Ash.Query.filter(inserted_at < ^cutoff)
          |> Ash.read!(tenant: facility.id, authorize?: false)

        Enum.each(stale, fn n ->
          Ash.destroy!(n, tenant: facility.id, authorize?: false)
        end)

        acc + length(stale)
      end)

    if deleted > 0 do
      Logger.info(
        "PruneOldNotifications: removed #{deleted} rows older than #{@retention_days} days"
      )
    end

    :ok
  end
end
