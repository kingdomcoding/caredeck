defmodule CaredeckWeb.Kitchen.DayEditorTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Kitchen, Org}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "DE #{suffix}", slug: "de-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "DE Home", slug: "de-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-de-#{suffix}",
          name: "Team Kitchen",
          role_kind: :kitchen,
          facility_id: facility.id,
          password: "phase8-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    soup =
      Kitchen.Product
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, name: "Soup", category: :dinner},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    stew =
      Kitchen.Product
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, name: "Stew", category: :dinner},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    %{facility: facility, team: team, soup: soup, stew: stew}
  end

  test "signed-in team-kitchen sees 6 category sections", ctx do
    conn = sign_in_team(ctx.conn, ctx.team)
    today_iso = Date.utc_today() |> Date.to_iso8601()
    {:ok, _view, html} = live(conn, ~p"/kitchen/weekly-menu/#{today_iso}")

    for label <- ~w(Breakfast Lunch Dinner Drinks Fruit Snack) do
      assert html =~ label
    end
  end

  test "clicking a product upserts a DayMenuSlot and re-renders the selection", ctx do
    conn = sign_in_team(ctx.conn, ctx.team)
    today_iso = Date.utc_today() |> Date.to_iso8601()
    {:ok, view, _html} = live(conn, ~p"/kitchen/weekly-menu/#{today_iso}")

    view
    |> element(
      "button[phx-click=pick][phx-value-category=dinner][phx-value-product_id='#{ctx.soup.id}']"
    )
    |> render_click()

    slots = Kitchen.DayMenuSlot |> Ash.read!(tenant: ctx.facility.id, authorize?: false)
    dinner = Enum.find(slots, &(&1.category == :dinner))
    assert dinner.product_id == ctx.soup.id

    view
    |> element(
      "button[phx-click=pick][phx-value-category=dinner][phx-value-product_id='#{ctx.stew.id}']"
    )
    |> render_click()

    slots = Kitchen.DayMenuSlot |> Ash.read!(tenant: ctx.facility.id, authorize?: false)
    dinner = Enum.find(slots, &(&1.category == :dinner))
    assert dinner.product_id == ctx.stew.id

    assert length(slots) == 1
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end
end
