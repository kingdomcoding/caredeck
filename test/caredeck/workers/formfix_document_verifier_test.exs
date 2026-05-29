defmodule Caredeck.Workers.FormfixDocumentVerifierTest do
  use Caredeck.DataCase, async: false
  use Oban.Testing, repo: Caredeck.Repo

  alias Caredeck.{Formfix, Org, People}
  alias Caredeck.Formfix.{UploadedDocument}
  alias Caredeck.Workers.FormfixDocumentVerifier

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "AV #{suffix}", slug: "av-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "AV Home", slug: "av-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    resident =
      People.Resident
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, first_name: "Anne", last_name: "Smith"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    application =
      Formfix.Application
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, resident_id: resident.id},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    {:ok, doc} =
      UploadedDocument
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          application_id: application.id,
          section_key: :assets,
          document_key: :property_deed,
          s3_key: "stub/key.pdf",
          original_filename: "deed.pdf"
        },
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create(tenant: facility.id, authorize?: false)

    %{facility: facility, doc: doc}
  end

  test "stub engine transitions :pending → :verified with timestamp", ctx do
    perform_job(FormfixDocumentVerifier, %{
      "document_id" => ctx.doc.id,
      "facility_id" => ctx.facility.id
    })

    updated = Ash.get!(UploadedDocument, ctx.doc.id, tenant: ctx.facility.id, authorize?: false)
    assert updated.state == :verified
    assert updated.verified_at != nil
  end

  test "unknown engine raises", ctx do
    Application.put_env(:caredeck, :formfix_verification_engine, :ocr)

    on_exit(fn ->
      Application.put_env(:caredeck, :formfix_verification_engine, :stub)
    end)

    assert_raise RuntimeError, ~r/formfix_verification_engine/, fn ->
      perform_job(FormfixDocumentVerifier, %{
        "document_id" => ctx.doc.id,
        "facility_id" => ctx.facility.id
      })
    end
  end
end
