defmodule Caredeck.Workers.ExpireStaleInvitations do
  use Oban.Worker, queue: :default, max_attempts: 3

  require Ash.Query
  require Logger

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now()

    facilities = Caredeck.Org.Facility |> Ash.read!(authorize?: false)

    deleted =
      Enum.reduce(facilities, 0, fn facility, acc ->
        stale =
          Caredeck.People.RelativeInvitation
          |> Ash.Query.filter(expires_at < ^now and is_nil(accepted_at))
          |> Ash.read!(tenant: facility.id, authorize?: false)

        Enum.each(stale, fn invitation ->
          Ash.destroy!(invitation, tenant: facility.id, authorize?: false)
        end)

        acc + length(stale)
      end)

    if deleted > 0 do
      Logger.info("ExpireStaleInvitations: deleted #{deleted} stale invitations")
    end

    :ok
  end
end
