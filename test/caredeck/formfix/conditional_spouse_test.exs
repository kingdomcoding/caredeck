defmodule Caredeck.Aid.ConditionalSpouseTest do
  use Caredeck.DataCase, async: false

  alias Caredeck.Aid.{Application, ApplicationSection, Applications, SectionSeeder, SectionWriter}
  alias Caredeck.{Org, People}

  require Ash.Query

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "CS #{suffix}", slug: "cs-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "CS Home", slug: "cs-home-#{suffix}"},
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

  test "saving marital_status :married adds spouse section", ctx do
    :ok =
      SectionWriter.save_answers!(ctx.application, :person_needing_care, %{
        "first_name" => "Anne",
        "last_name" => "Smith",
        "date_of_birth" => "1942-03-15",
        "marital_status" => "married",
        "postal_code" => "12345",
        "street" => "1 Main",
        "city" => "Townsville"
      })

    spouse =
      ApplicationSection
      |> Ash.Query.filter(application_id == ^ctx.application.id and section_key == :spouse)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert spouse != nil
    assert spouse.position == 14
  end

  test "saving marital_status :single does not add spouse section", ctx do
    :ok =
      SectionWriter.save_answers!(ctx.application, :person_needing_care, %{
        "first_name" => "Anne",
        "last_name" => "Smith",
        "date_of_birth" => "1942-03-15",
        "marital_status" => "single",
        "postal_code" => "12345",
        "street" => "1 Main",
        "city" => "Townsville"
      })

    spouse =
      ApplicationSection
      |> Ash.Query.filter(application_id == ^ctx.application.id and section_key == :spouse)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert spouse == nil
  end

  test "switching from :married back to :single removes the spouse section", ctx do
    :ok =
      SectionWriter.save_answers!(ctx.application, :person_needing_care, %{
        "first_name" => "Anne",
        "marital_status" => "married"
      })

    spouse =
      ApplicationSection
      |> Ash.Query.filter(application_id == ^ctx.application.id and section_key == :spouse)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert spouse != nil

    :ok =
      SectionWriter.save_answers!(ctx.application, :person_needing_care, %{
        "marital_status" => "divorced"
      })

    :ok = Applications.refresh_conditional_sections(ctx.application)

    spouse_after =
      ApplicationSection
      |> Ash.Query.filter(application_id == ^ctx.application.id and section_key == :spouse)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert spouse_after == nil
  end
end
