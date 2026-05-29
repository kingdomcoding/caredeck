defmodule Caredeck.Workers.FormfixDigestDispatch do
  use Oban.Worker, queue: :mailers, max_attempts: 3

  alias Caredeck.Org.Facility

  @impl true
  def perform(%Oban.Job{}) do
    Facility
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn fac ->
      %{facility_id: fac.id}
      |> Caredeck.Workers.FormfixDigest.new()
      |> Oban.insert!()
    end)

    :ok
  end
end
