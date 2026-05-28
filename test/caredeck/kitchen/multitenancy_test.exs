defmodule Caredeck.Kitchen.MultitenancyTest do
  use Caredeck.DataCase, async: false

  alias Caredeck.{Kitchen, Org, People}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "MT Kitchen #{suffix}", slug: "mtk-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility_a = create_facility(district, "A", "mtk-a-#{suffix}")
    facility_b = create_facility(district, "B", "mtk-b-#{suffix}")

    product_a =
      Kitchen.Product
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility_a.id, name: "Soup", category: :dinner},
        tenant: facility_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility_a.id, authorize?: false)

    resident_a =
      People.Resident
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility_a.id, first_name: "X", last_name: "Y"},
        tenant: facility_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility_a.id, authorize?: false)

    day_menu_a =
      Kitchen.DayMenu
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility_a.id, date: Date.utc_today()},
        tenant: facility_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility_a.id, authorize?: false)

    order_a =
      Kitchen.ResidentMealOrder
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility_a.id,
          resident_id: resident_a.id,
          date: Date.utc_today(),
          category: :dinner,
          product_id: product_a.id
        },
        tenant: facility_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility_a.id, authorize?: false)

    %{
      facility_a: facility_a,
      facility_b: facility_b,
      product_a: product_a,
      day_menu_a: day_menu_a,
      order_a: order_a
    }
  end

  defp create_facility(district, name, slug) do
    Org.Facility
    |> Ash.Changeset.for_create(
      :create,
      %{district_id: district.id, name: name, slug: slug},
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  test "Product without tenant raises", _ctx do
    assert_raise Ash.Error.Invalid, fn -> Ash.read!(Kitchen.Product, authorize?: false) end
  end

  test "DayMenu without tenant raises", _ctx do
    assert_raise Ash.Error.Invalid, fn -> Ash.read!(Kitchen.DayMenu, authorize?: false) end
  end

  test "ResidentMealOrder without tenant raises", _ctx do
    assert_raise Ash.Error.Invalid, fn ->
      Ash.read!(Kitchen.ResidentMealOrder, authorize?: false)
    end
  end

  test "Product cross-facility read returns 0 rows", ctx do
    rows = Kitchen.Product |> Ash.read!(tenant: ctx.facility_b.id, authorize?: false)
    refute Enum.any?(rows, &(&1.id == ctx.product_a.id))
  end

  test "DayMenu cross-facility read returns 0 rows", ctx do
    rows = Kitchen.DayMenu |> Ash.read!(tenant: ctx.facility_b.id, authorize?: false)
    refute Enum.any?(rows, &(&1.id == ctx.day_menu_a.id))
  end

  test "ResidentMealOrder cross-facility read returns 0 rows", ctx do
    rows = Kitchen.ResidentMealOrder |> Ash.read!(tenant: ctx.facility_b.id, authorize?: false)
    refute Enum.any?(rows, &(&1.id == ctx.order_a.id))
  end
end
