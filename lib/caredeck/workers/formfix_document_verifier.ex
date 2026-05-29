defmodule Caredeck.Workers.FormfixDocumentVerifier do
  use Oban.Worker, queue: :aid, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"document_id" => id, "facility_id" => fid}}) do
    Caredeck.Formfix.Verifier.run(id, fid)
  end
end
