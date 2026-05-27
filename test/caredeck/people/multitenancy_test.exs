defmodule Caredeck.People.MultitenancyTest do
  use Caredeck.DataCase, async: false

  alias Caredeck.{Org, People}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "Tenancy Test", slug: "tenancy-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility_a =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "Tenant A", slug: "tenant-a-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility_b =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "Tenant B", slug: "tenant-b-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    a_resident =
      People.Resident
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility_a.id, first_name: "A", last_name: "Person"},
        tenant: facility_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility_a.id, authorize?: false)

    %{facility_a: facility_a, facility_b: facility_b, a_resident: a_resident}
  end

  test "reading residents in tenant B does not return tenant A residents", ctx do
    rows = Ash.read!(People.Resident, tenant: ctx.facility_b.id, authorize?: false)
    refute Enum.any?(rows, &(&1.id == ctx.a_resident.id))
  end

  test "reading residents with the correct tenant returns its rows", ctx do
    rows = Ash.read!(People.Resident, tenant: ctx.facility_a.id, authorize?: false)
    assert Enum.any?(rows, &(&1.id == ctx.a_resident.id))
  end

  test "reading residents without a tenant raises", _ctx do
    assert_raise Ash.Error.Invalid, fn ->
      Ash.read!(People.Resident, authorize?: false)
    end
  end
end
