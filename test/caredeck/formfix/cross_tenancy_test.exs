defmodule Caredeck.Aid.CrossTenancyTest do
  use Caredeck.DataCase, async: false

  alias Caredeck.Aid.{Application, ApplicationSection, SectionSeeder}
  alias Caredeck.{Org, People}

  require Ash.Query

  setup do
    suffix = :erlang.unique_integer([:positive])
    district = create_district(suffix)
    a = create_facility(district, "A", "aid-a-#{suffix}")
    b = create_facility(district, "B", "aid-b-#{suffix}")
    resident_a = create_resident(a, "Anne", "Smith")

    app_a =
      Application
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: a.id, resident_id: resident_a.id},
        tenant: a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: a.id, authorize?: false)

    :ok = SectionSeeder.materialise!(app_a)

    %{facility_a: a, facility_b: b, app_a: app_a}
  end

  test "Application read without tenant raises" do
    assert_raise Ash.Error.Invalid, fn ->
      Ash.read!(Application, authorize?: false)
    end
  end

  test "ApplicationSection read without tenant raises" do
    assert_raise Ash.Error.Invalid, fn ->
      Ash.read!(ApplicationSection, authorize?: false)
    end
  end

  test "Application cross-facility read returns 0 rows", ctx do
    rows = Application |> Ash.read!(tenant: ctx.facility_b.id, authorize?: false)
    refute Enum.any?(rows, &(&1.id == ctx.app_a.id))
  end

  test "ApplicationSection cross-facility read returns 0 rows", ctx do
    rows = ApplicationSection |> Ash.read!(tenant: ctx.facility_b.id, authorize?: false)
    assert rows == []
  end

  test "SectionSeeder.materialise!/1 produces 13 sections, positions 1..13", ctx do
    sections =
      ApplicationSection
      |> Ash.Query.filter(application_id == ^ctx.app_a.id)
      |> Ash.Query.sort(position: :asc)
      |> Ash.read!(tenant: ctx.facility_a.id, authorize?: false)

    assert length(sections) == 13
    assert Enum.map(sections, & &1.position) == Enum.to_list(1..13)
    assert Enum.all?(sections, &(&1.status == :not_started))
  end

  test "SectionSeeder is idempotent (re-running upserts, count stays 13)", ctx do
    :ok = SectionSeeder.materialise!(ctx.app_a)

    count =
      ApplicationSection
      |> Ash.Query.filter(application_id == ^ctx.app_a.id)
      |> Ash.read!(tenant: ctx.facility_a.id, authorize?: false)
      |> length()

    assert count == 13
  end

  test "Application starts in :draft state", ctx do
    assert ctx.app_a.state == :draft
  end

  test "Application :submit transition flips state to :submitted with timestamp", ctx do
    # First need to be in :ready_to_submit
    {:ok, ready} =
      ctx.app_a
      |> Ash.Changeset.for_update(:mark_ready_to_submit, %{},
        tenant: ctx.facility_a.id,
        authorize?: false
      )
      |> Ash.update(tenant: ctx.facility_a.id, authorize?: false)

    {:ok, submitted} =
      ready
      |> Ash.Changeset.for_update(:submit, %{},
        tenant: ctx.facility_a.id,
        authorize?: false
      )
      |> Ash.update(tenant: ctx.facility_a.id, authorize?: false)

    assert submitted.state == :submitted
    assert submitted.submitted_at != nil
  end

  defp create_district(suffix) do
    Org.District
    |> Ash.Changeset.for_create(
      :create,
      %{name: "Aid #{suffix}", slug: "aid-#{suffix}"},
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  defp create_facility(d, name, slug) do
    Org.Facility
    |> Ash.Changeset.for_create(
      :create,
      %{district_id: d.id, name: name, slug: slug},
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  defp create_resident(f, first, last) do
    People.Resident
    |> Ash.Changeset.for_create(
      :create,
      %{facility_id: f.id, first_name: first, last_name: last},
      tenant: f.id,
      authorize?: false
    )
    |> Ash.create!(tenant: f.id, authorize?: false)
  end
end
