defmodule Caredeck.Workers.AidDocumentVerifier do
  use Oban.Worker, queue: :aid, max_attempts: 3

  @mix_env Mix.env()

  alias Caredeck.Aid.UploadedDocument

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"document_id" => id, "facility_id" => fid}}) do
    engine = Application.get_env(:caredeck, :aid_verification_engine, :stub)

    if engine == :stub and @mix_env != :test, do: Process.sleep(1_000)

    doc = Ash.get!(UploadedDocument, id, tenant: fid, authorize?: false)

    doc =
      doc
      |> Ash.Changeset.for_update(:start_verification, %{},
        tenant: fid,
        authorize?: false
      )
      |> Ash.update!(tenant: fid, authorize?: false)

    case engine do
      :stub ->
        doc
        |> Ash.Changeset.for_update(:mark_verified, %{}, tenant: fid, authorize?: false)
        |> Ash.update!(tenant: fid, authorize?: false)

      other ->
        raise "aid_verification_engine #{inspect(other)} is not implemented"
    end

    application =
      Ash.get!(Caredeck.Aid.Application, doc.application_id,
        tenant: fid,
        authorize?: false
      )

    :ok = Caredeck.Aid.Applications.recompute_status(application)

    :ok
  end
end
