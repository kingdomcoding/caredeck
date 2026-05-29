defmodule Caredeck.Formfix.ProgressCalculationTest do
  use Caredeck.DataCase, async: false

  alias Caredeck.Formfix.{Application, ApplicationSection, SectionSeeder}
  alias Caredeck.{Org, People}

  require Ash.Query

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "PC #{suffix}", slug: "pc-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "PC Home", slug: "pc-home-#{suffix}"},
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

  defp progress(application, facility) do
    Application
    |> Ash.Query.filter(id == ^application.id)
    |> Ash.Query.load(:progress_percent)
    |> Ash.read_one!(tenant: facility.id, authorize?: false)
    |> Map.get(:progress_percent)
  end

  defp mark_n_sections!(application, facility, n) do
    ApplicationSection
    |> Ash.Query.filter(application_id == ^application.id)
    |> Ash.Query.sort(position: :asc)
    |> Ash.Query.limit(n)
    |> Ash.read!(tenant: facility.id, authorize?: false)
    |> Enum.each(fn s ->
      s
      |> Ash.Changeset.for_update(:transition, %{status: :complete},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.update!(tenant: facility.id, authorize?: false)
    end)
  end

  test "0/13 sections complete → 0%", ctx do
    assert progress(ctx.application, ctx.facility) == 0
  end

  test "7/13 sections complete → ~54%", ctx do
    mark_n_sections!(ctx.application, ctx.facility, 7)
    pct = progress(ctx.application, ctx.facility)
    assert pct in [53, 54]
  end

  test "13/13 sections complete → 100%", ctx do
    mark_n_sections!(ctx.application, ctx.facility, 13)
    assert progress(ctx.application, ctx.facility) == 100
  end

  test "mixing :complete and :skipped both count", ctx do
    sections =
      ApplicationSection
      |> Ash.Query.filter(application_id == ^ctx.application.id)
      |> Ash.Query.sort(position: :asc)
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    [first, second | _] = sections

    [{first, :complete}, {second, :skipped}]
    |> Enum.each(fn {s, st} ->
      s
      |> Ash.Changeset.for_update(:transition, %{status: st},
        tenant: ctx.facility.id,
        authorize?: false
      )
      |> Ash.update!(tenant: ctx.facility.id, authorize?: false)
    end)

    assert progress(ctx.application, ctx.facility) == 15
  end
end
