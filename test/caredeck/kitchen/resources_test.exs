defmodule Caredeck.Kitchen.ResourcesTest do
  use Caredeck.DataCase, async: false

  alias Caredeck.Accounts
  alias Caredeck.Kitchen
  alias Caredeck.Org

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "Kitchen Rsrc #{suffix}", slug: "krsrc-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility_a = create_facility(district, "Kitchen A", "krsrc-a-#{suffix}")
    facility_b = create_facility(district, "Kitchen B", "krsrc-b-#{suffix}")

    %{facility_a: facility_a, facility_b: facility_b, suffix: suffix}
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

  defp create_product(facility, name, category \\ :lunch) do
    Kitchen.Product
    |> Ash.Changeset.for_create(
      :create,
      %{facility_id: facility.id, name: name, category: category},
      tenant: facility.id,
      authorize?: false
    )
    |> Ash.create(tenant: facility.id, authorize?: false)
  end

  defp create_kitchen_team(facility, suffix) do
    Accounts.TeamIdentity
    |> Ash.Changeset.for_create(
      :register_with_password,
      %{
        handle: "team-k-#{suffix}",
        name: "Team K",
        role_kind: :kitchen,
        facility_id: facility.id,
        password: "phase8-test-pass"
      },
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  test "Product create + read are tenant-scoped", ctx do
    {:ok, _} = create_product(ctx.facility_a, "Schnitzel")
    a_rows = Kitchen.Product |> Ash.read!(tenant: ctx.facility_a.id, authorize?: false)
    b_rows = Kitchen.Product |> Ash.read!(tenant: ctx.facility_b.id, authorize?: false)

    assert length(a_rows) == 1
    assert b_rows == []
  end

  test "Product read without tenant raises", _ctx do
    assert_raise Ash.Error.Invalid, fn ->
      Ash.read!(Kitchen.Product, authorize?: false)
    end
  end

  test "Product unique_name_per_facility_per_category prevents duplicates", ctx do
    {:ok, _} = create_product(ctx.facility_a, "Pasta")
    assert {:error, _} = create_product(ctx.facility_a, "Pasta")
  end

  test "MenuTemplate one_active_per_facility partial-unique", ctx do
    {:ok, _} =
      Kitchen.MenuTemplate
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: ctx.facility_a.id, name: "Week A", is_active: true},
        tenant: ctx.facility_a.id,
        authorize?: false
      )
      |> Ash.create(tenant: ctx.facility_a.id, authorize?: false)

    assert {:error, _} =
             Kitchen.MenuTemplate
             |> Ash.Changeset.for_create(
               :create,
               %{facility_id: ctx.facility_a.id, name: "Week B", is_active: true},
               tenant: ctx.facility_a.id,
               authorize?: false
             )
             |> Ash.create(tenant: ctx.facility_a.id, authorize?: false)
  end

  test "DayMenuSlot upsert replaces product_id without raising", ctx do
    {:ok, p1} = create_product(ctx.facility_a, "Soup", :dinner)
    {:ok, p2} = create_product(ctx.facility_a, "Stew", :dinner)

    day_menu =
      Kitchen.DayMenu
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: ctx.facility_a.id, date: Date.utc_today()},
        tenant: ctx.facility_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: ctx.facility_a.id, authorize?: false)

    Kitchen.DayMenuSlot
    |> Ash.Changeset.for_create(
      :create,
      %{
        facility_id: ctx.facility_a.id,
        day_menu_id: day_menu.id,
        category: :dinner,
        product_id: p1.id
      },
      tenant: ctx.facility_a.id,
      authorize?: false
    )
    |> Ash.create!(tenant: ctx.facility_a.id, authorize?: false)

    upserted =
      Kitchen.DayMenuSlot
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: ctx.facility_a.id,
          day_menu_id: day_menu.id,
          category: :dinner,
          product_id: p2.id
        },
        tenant: ctx.facility_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: ctx.facility_a.id, authorize?: false)

    assert upserted.product_id == p2.id

    slots =
      Kitchen.DayMenuSlot
      |> Ash.read!(tenant: ctx.facility_a.id, authorize?: false)

    assert length(slots) == 1
  end

  test "ResidentMealOrder upsert overwrites product on same (resident,date,category)", ctx do
    {:ok, p1} = create_product(ctx.facility_a, "Apple")
    {:ok, p2} = create_product(ctx.facility_a, "Banana")

    resident =
      Caredeck.People.Resident
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: ctx.facility_a.id, first_name: "Hans", last_name: "Klein"},
        tenant: ctx.facility_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: ctx.facility_a.id, authorize?: false)

    today = Date.utc_today()

    Kitchen.ResidentMealOrder
    |> Ash.Changeset.for_create(
      :create,
      %{
        facility_id: ctx.facility_a.id,
        resident_id: resident.id,
        date: today,
        category: :lunch,
        product_id: p1.id
      },
      tenant: ctx.facility_a.id,
      authorize?: false
    )
    |> Ash.create!(tenant: ctx.facility_a.id, authorize?: false)

    upserted =
      Kitchen.ResidentMealOrder
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: ctx.facility_a.id,
          resident_id: resident.id,
          date: today,
          category: :lunch,
          product_id: p2.id
        },
        tenant: ctx.facility_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: ctx.facility_a.id, authorize?: false)

    assert upserted.product_id == p2.id

    rows =
      Kitchen.ResidentMealOrder
      |> Ash.read!(tenant: ctx.facility_a.id, authorize?: false)

    assert length(rows) == 1
  end

  test "non-:kitchen team cannot update a Product but can read", ctx do
    {:ok, product} = create_product(ctx.facility_a, "Tea", :drinks)

    care_team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-care-rsrc-#{ctx.suffix}",
          name: "Team Care",
          role_kind: :care,
          facility_id: ctx.facility_a.id,
          password: "phase8-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    assert {:ok, _} =
             Ash.read(Kitchen.Product, tenant: ctx.facility_a.id, actor: care_team)

    assert {:error, _} =
             product
             |> Ash.Changeset.for_update(:update, %{name: "Coffee"},
               tenant: ctx.facility_a.id,
               actor: care_team
             )
             |> Ash.update(tenant: ctx.facility_a.id, actor: care_team)

    kitchen_team = create_kitchen_team(ctx.facility_a, ctx.suffix)

    assert {:ok, _} =
             product
             |> Ash.Changeset.for_update(:update, %{name: "Coffee"},
               tenant: ctx.facility_a.id,
               actor: kitchen_team
             )
             |> Ash.update(tenant: ctx.facility_a.id, actor: kitchen_team)
  end
end
