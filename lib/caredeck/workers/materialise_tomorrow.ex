defmodule Caredeck.Workers.MaterialiseTomorrow do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Caredeck.Kitchen.Materialise

  @impl Oban.Worker
  def perform(_job) do
    tomorrow = Date.add(Date.utc_today(), 1)

    Caredeck.Org.Facility
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn f -> Materialise.materialise_day(f.id, tomorrow) end)

    :ok
  end
end
