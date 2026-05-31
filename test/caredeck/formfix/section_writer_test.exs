defmodule Caredeck.Formfix.SectionWriterTest do
  use Caredeck.DataCase, async: false

  alias Caredeck.Formfix.{
    Application,
    ApplicationSection,
    SectionAnswer,
    SectionSeeder,
    SectionWriter
  }

  alias Caredeck.{Org, People}

  require Ash.Query

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "SW #{suffix}", slug: "sw-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "SW Home", slug: "sw-home-#{suffix}"},
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
      Application
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, resident_id: resident.id},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    :ok = SectionSeeder.materialise!(application)

    %{facility: facility, application: application}
  end

  test "saves 3 fields → asserts 3 SectionAnswer rows", ctx do
    :ok =
      SectionWriter.save_answers!(ctx.application, :person_needing_care, %{
        "first_name" => "Anne",
        "last_name" => "Smith",
        "date_of_birth" => "1942-03-15"
      })

    rows =
      SectionAnswer
      |> Ash.Query.filter(application_id == ^ctx.application.id)
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert length(rows) == 3
    assert Enum.find(rows, &(&1.field_key == :first_name)).value_text == "Anne"
    assert Enum.find(rows, &(&1.field_key == :date_of_birth)).value_date == ~D[1942-03-15]
  end

  test "saving the same field twice upserts (single row)", ctx do
    :ok =
      SectionWriter.save_answers!(ctx.application, :person_needing_care, %{"first_name" => "Anne"})

    :ok =
      SectionWriter.save_answers!(ctx.application, :person_needing_care, %{"first_name" => "Ann"})

    rows =
      SectionAnswer
      |> Ash.Query.filter(application_id == ^ctx.application.id)
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert length(rows) == 1
    assert hd(rows).value_text == "Ann"
  end

  test "all required fields present → ApplicationSection flips to :complete", ctx do
    :ok =
      SectionWriter.save_answers!(ctx.application, :person_needing_care, %{
        "first_name" => "Anne",
        "last_name" => "Smith",
        "date_of_birth" => "1942-03-15",
        "marital_status" => "widowed",
        "postal_code" => "12345",
        "street" => "1 Main",
        "city" => "Townsville"
      })

    section =
      ApplicationSection
      |> Ash.Query.filter(
        application_id == ^ctx.application.id and section_key == :person_needing_care
      )
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert section.status == :complete
  end

  test "partial save → ApplicationSection flips to :in_progress", ctx do
    :ok = SectionWriter.save_answers!(ctx.application, :applicant, %{"first_name" => "Anne"})

    section =
      ApplicationSection
      |> Ash.Query.filter(application_id == ^ctx.application.id and section_key == :applicant)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert section.status == :in_progress
  end
end
