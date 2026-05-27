defmodule Caredeck.People.ResidentLifecycleTest do
  use Caredeck.DataCase, async: false

  alias Caredeck.{Org, People}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "Lifecycle Test", slug: "lifecycle-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "Lifecycle Home", slug: "lifecycle-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    %{facility: facility}
  end

  test "a new resident starts in :admitted state", %{facility: facility} do
    {:ok, r} =
      Ash.create(
        People.Resident,
        %{
          facility_id: facility.id,
          first_name: "Test",
          last_name: "Newcomer"
        },
        tenant: facility.id,
        authorize?: false
      )

    assert r.lifecycle_state == :admitted
    assert r.admitted_at
  end

  test "discharge transitions :admitted → :discharged", %{facility: facility} do
    {:ok, r} =
      Ash.create(
        People.Resident,
        %{facility_id: facility.id, first_name: "Disc", last_name: "Harge"},
        tenant: facility.id,
        authorize?: false
      )

    discharged =
      r
      |> Ash.Changeset.for_update(:discharge, %{}, tenant: facility.id, authorize?: false)
      |> Ash.update!(tenant: facility.id, authorize?: false)

    assert discharged.lifecycle_state == :discharged
    assert discharged.discharged_at
  end

  test "deceased state cannot be reverted to admitted", %{facility: facility} do
    {:ok, r} =
      Ash.create(
        People.Resident,
        %{facility_id: facility.id, first_name: "Term", last_name: "Inal"},
        tenant: facility.id,
        authorize?: false
      )

    deceased =
      r
      |> Ash.Changeset.for_update(:mark_deceased, %{}, tenant: facility.id, authorize?: false)
      |> Ash.update!(tenant: facility.id, authorize?: false)

    assert deceased.lifecycle_state == :deceased

    assert_raise Ash.Error.Invalid, fn ->
      deceased
      |> Ash.Changeset.for_update(:readmit, %{}, tenant: facility.id, authorize?: false)
      |> Ash.update!(tenant: facility.id, authorize?: false)
    end
  end
end
