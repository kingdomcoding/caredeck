defmodule Caredeck.Workers.MaterialiseTomorrowTest do
  use Caredeck.DataCase, async: false

  alias Caredeck.{Kitchen, Org}
  alias Caredeck.Workers.MaterialiseTomorrow

  require Ash.Query

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "MT #{suffix}", slug: "mt-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "MT Home", slug: "mt-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    products =
      for cat <- Kitchen.MealCategory.all() do
        Kitchen.Product
        |> Ash.Changeset.for_create(
          :create,
          %{facility_id: facility.id, name: "Default #{cat}", category: cat},
          tenant: facility.id,
          authorize?: false
        )
        |> Ash.create!(tenant: facility.id, authorize?: false)
      end

    template =
      Kitchen.MenuTemplate
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, name: "Week", is_active: true},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    products_by_cat = Map.new(products, &{&1.category, &1.id})

    for day <- ~w(monday tuesday wednesday thursday friday saturday sunday)a,
        cat <- Kitchen.MealCategory.all() do
      Kitchen.MenuTemplateSlot
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          menu_template_id: template.id,
          day_of_week: day,
          category: cat,
          product_id: Map.fetch!(products_by_cat, cat)
        },
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)
    end

    %{facility: facility}
  end

  test "creates tomorrow's DayMenu + 6 slots for every facility", ctx do
    MaterialiseTomorrow.perform(%Oban.Job{})

    tomorrow = Date.add(Date.utc_today(), 1)

    menus =
      Kitchen.DayMenu
      |> Ash.Query.filter(date == ^tomorrow)
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert [_menu] = menus

    slots = Kitchen.DayMenuSlot |> Ash.read!(tenant: ctx.facility.id, authorize?: false)
    assert length(slots) == 6
  end

  test "re-running the worker is idempotent", ctx do
    MaterialiseTomorrow.perform(%Oban.Job{})
    MaterialiseTomorrow.perform(%Oban.Job{})

    tomorrow = Date.add(Date.utc_today(), 1)

    menus =
      Kitchen.DayMenu
      |> Ash.Query.filter(date == ^tomorrow)
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    slots = Kitchen.DayMenuSlot |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert length(menus) == 1
    assert length(slots) == 6
  end
end
