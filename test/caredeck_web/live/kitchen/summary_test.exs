defmodule CaredeckWeb.Kitchen.SummaryTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Kitchen, Org, People}
  alias CaredeckWeb.Endpoint

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "SM #{suffix}", slug: "sm-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "SM Home", slug: "sm-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-sm-#{suffix}",
          name: "Team Kitchen",
          role_kind: :kitchen,
          facility_id: facility.id,
          password: "phase8-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    %{facility: facility, team: team}
  end

  defp create_resident(facility, first) do
    People.Resident
    |> Ash.Changeset.for_create(
      :create,
      %{facility_id: facility.id, first_name: first, last_name: "Resident"},
      tenant: facility.id,
      authorize?: false
    )
    |> Ash.create!(tenant: facility.id, authorize?: false)
  end

  defp create_product(facility, name) do
    Kitchen.Product
    |> Ash.Changeset.for_create(
      :create,
      %{facility_id: facility.id, name: name, category: :lunch},
      tenant: facility.id,
      authorize?: false
    )
    |> Ash.create!(tenant: facility.id, authorize?: false)
  end

  defp create_order(facility, resident, product) do
    Kitchen.ResidentMealOrder
    |> Ash.Changeset.for_create(
      :create,
      %{
        facility_id: facility.id,
        resident_id: resident.id,
        date: Date.utc_today(),
        category: :lunch,
        product_id: product.id,
        state: :ordered
      },
      tenant: facility.id,
      authorize?: false
    )
    |> Ash.create!(tenant: facility.id, authorize?: false)
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end

  test "team-kitchen sees empty state for every category", ctx do
    conn = sign_in_team(ctx.conn, ctx.team)
    {:ok, _view, html} = live(conn, ~p"/kitchen/summary")
    assert html =~ "Today&#39;s orders"
    assert html =~ "No orders yet"
  end

  test "aggregates 3 orders into correct desc counts", ctx do
    p_a = create_product(ctx.facility, "Schnitzel")
    p_b = create_product(ctx.facility, "Vegetarian curry")

    r1 = create_resident(ctx.facility, "R1")
    r2 = create_resident(ctx.facility, "R2")
    r3 = create_resident(ctx.facility, "R3")

    create_order(ctx.facility, r1, p_a)
    create_order(ctx.facility, r2, p_a)
    create_order(ctx.facility, r3, p_b)

    conn = sign_in_team(ctx.conn, ctx.team)
    {:ok, _view, html} = live(conn, ~p"/kitchen/summary")

    assert html =~ "Schnitzel"
    assert html =~ "×2"
    assert html =~ "Vegetarian curry"
    assert html =~ "×1"

    schnitzel_pos = :binary.match(html, "Schnitzel") |> elem(0)
    curry_pos = :binary.match(html, "Vegetarian curry") |> elem(0)
    assert schnitzel_pos < curry_pos
  end

  test "broadcast order_changed re-aggregates", ctx do
    conn = sign_in_team(ctx.conn, ctx.team)
    {:ok, view, _html} = live(conn, ~p"/kitchen/summary")

    p_a = create_product(ctx.facility, "Soup")
    r1 = create_resident(ctx.facility, "X1")
    create_order(ctx.facility, r1, p_a)

    Endpoint.broadcast("facility:#{ctx.facility.id}:kitchen", "order_changed", %{})

    html = render(view)
    assert html =~ "Soup"
    assert html =~ "×1"
  end

  test "anonymous GET /kitchen/summary redirects", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/team/sign-in"}}} = live(conn, ~p"/kitchen/summary")
  end
end
