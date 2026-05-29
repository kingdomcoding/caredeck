defmodule Caredeck.Formfix.Verifier do
  alias Caredeck.Formfix.{Application, UploadedDocument}

  @mix_env Mix.env()

  def run(id, fid) do
    engine = Elixir.Application.get_env(:caredeck, :formfix_verification_engine, :stub)

    if engine == :stub and @mix_env != :test, do: Process.sleep(1_000)

    doc =
      UploadedDocument
      |> Ash.get!(id, tenant: fid, authorize?: false)

    doc =
      doc
      |> Ash.Changeset.for_update(:start_verification, %{}, tenant: fid, authorize?: false)
      |> Ash.update!(tenant: fid, authorize?: false)

    case engine do
      :stub ->
        doc
        |> Ash.Changeset.for_update(:mark_verified, %{}, tenant: fid, authorize?: false)
        |> Ash.update!(tenant: fid, authorize?: false)

      other ->
        raise "formfix_verification_engine #{inspect(other)} is not implemented"
    end

    application = Ash.get!(Application, doc.application_id, tenant: fid, authorize?: false)
    :ok = Caredeck.Formfix.Applications.recompute_status(application)

    :ok
  end

  def run_async(id, fid) do
    Task.Supervisor.start_child(Caredeck.TaskSupervisor, fn -> run(id, fid) end)
  end
end
