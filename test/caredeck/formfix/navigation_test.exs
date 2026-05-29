defmodule Caredeck.Formfix.NavigationTest do
  use Caredeck.DataCase, async: false

  alias Caredeck.Formfix.{Application, ApplicationSection, Applications, SectionSeeder, SectionWriter}
  alias Caredeck.{Org, People}

  require Ash.Query

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "Nav #{suffix}", slug: "nav-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "Nav Home", slug: "nav-home-#{suffix}"},
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

  describe "next_section_key/2" do
    test "skips inapplicable partner sections (single applicant)", ctx do
      assert Applications.next_section_key(ctx.application, :income) == :assets
      assert Applications.next_section_key(ctx.application, :assets) == :gifts_given
      assert Applications.next_section_key(ctx.application, :gifts_given) == :expenses
    end

    test "returns nil when on the last materialised section", ctx do
      assert Applications.next_section_key(ctx.application, :foreign_nationality) == nil
    end

    test "honours newly-materialised partner sections after marital status flips", ctx do
      :ok =
        SectionWriter.save_answers!(ctx.application, :person_needing_care, %{
          "marital_status" => "married"
        })

      assert Applications.next_section_key(ctx.application, :income) == :income_partner
      assert Applications.next_section_key(ctx.application, :income_partner) == :assets
    end
  end

  describe "next_actionable_section/1" do
    test "picks the first :in_progress section over later :not_started ones", ctx do
      sections =
        ApplicationSection
        |> Ash.Query.filter(application_id == ^ctx.application.id)
        |> Ash.Query.sort(position: :asc)
        |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

      [welcome, person_needing_care | _] = sections

      welcome
      |> Ash.Changeset.for_update(:transition, %{status: :complete},
        tenant: ctx.facility.id,
        authorize?: false
      )
      |> Ash.update!(tenant: ctx.facility.id, authorize?: false)

      person_needing_care
      |> Ash.Changeset.for_update(:transition, %{status: :in_progress},
        tenant: ctx.facility.id,
        authorize?: false
      )
      |> Ash.update!(tenant: ctx.facility.id, authorize?: false)

      next = Applications.next_actionable_section(ctx.application)
      assert next.section_key == :person_needing_care
    end

    test "falls back to the first :not_started when nothing is in_progress", ctx do
      next = Applications.next_actionable_section(ctx.application)
      assert next.section_key == :welcome
    end

    test "returns nil when every section is :complete or :skipped", ctx do
      ApplicationSection
      |> Ash.Query.filter(application_id == ^ctx.application.id)
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)
      |> Enum.each(fn s ->
        s
        |> Ash.Changeset.for_update(:transition, %{status: :complete},
          tenant: ctx.facility.id,
          authorize?: false
        )
        |> Ash.update!(tenant: ctx.facility.id, authorize?: false)
      end)

      assert Applications.next_actionable_section(ctx.application) == nil
    end
  end
end
