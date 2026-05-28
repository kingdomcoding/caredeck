defmodule CaredeckWeb.Kitchen.WeeklyMenuTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Kitchen, Org}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "WM #{suffix}", slug: "wm-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "WM Home", slug: "wm-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-wm-#{suffix}",
          name: "Team Kitchen",
          role_kind: :kitchen,
          facility_id: facility.id,
          password: "phase8-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    products =
      for cat <- Kitchen.MealCategory.all() do
        Kitchen.Product
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: facility.id,
            name: "Default #{cat}",
            category: cat
          },
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

    %{facility: facility, team: team}
  end

  test "signed-in team-kitchen sees the 7-day strip", ctx do
    conn = sign_in_team(ctx.conn, ctx.team)
    {:ok, _view, html} = live(conn, ~p"/kitchen/weekly-menu")

    assert html =~ "Weekly menu"

    for short <- ~w(Mon Tue Wed Thu Fri Sat Sun) do
      assert html =~ short
    end
  end

  test "clicking Materialise creates a DayMenu + 6 DayMenuSlot rows", ctx do
    conn = sign_in_team(ctx.conn, ctx.team)
    {:ok, view, _html} = live(conn, ~p"/kitchen/weekly-menu")

    today_iso = Date.utc_today() |> Date.to_iso8601()

    view
    |> element("button[phx-click=materialise][phx-value-date='#{today_iso}']")
    |> render_click()

    menus = Kitchen.DayMenu |> Ash.read!(tenant: ctx.facility.id, authorize?: false)
    slots = Kitchen.DayMenuSlot |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert length(menus) == 1
    assert length(slots) == 6
  end

  test "anonymous GET /kitchen/weekly-menu redirects to team sign-in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/team/sign-in"}}} = live(conn, ~p"/kitchen/weekly-menu")
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end
end
