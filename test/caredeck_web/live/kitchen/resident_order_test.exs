defmodule CaredeckWeb.Kitchen.ResidentOrderTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Kitchen, Org, People}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "RO #{suffix}", slug: "ro-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "RO Home", slug: "ro-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    care_team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-care-ro-#{suffix}",
          name: "Team Care",
          role_kind: :care,
          facility_id: facility.id,
          password: "phase8-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    resident =
      People.Resident
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, first_name: "Anna", last_name: "Becker"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    other_resident =
      People.Resident
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, first_name: "Otto", last_name: "Stranger"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user_a = register_user("a-ro-#{suffix}@example.test")

    Org.FacilityMembership
    |> Ash.Changeset.for_create(
      :create,
      %{facility_id: facility.id, user_id: user_a.id, role: :relative, source: :manual},
      authorize?: false
    )
    |> Ash.create!(authorize?: false)

    relative_a =
      People.Relative
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, user_id: user_a.id, display_name: "User A"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    People.RelativeOfResident
    |> Ash.Changeset.for_create(
      :create,
      %{
        facility_id: facility.id,
        relative_id: relative_a.id,
        resident_id: resident.id,
        relationship: :daughter
      },
      tenant: facility.id,
      authorize?: false
    )
    |> Ash.create!(tenant: facility.id, authorize?: false)

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

    %{
      facility: facility,
      care_team: care_team,
      resident: resident,
      other_resident: other_resident,
      user_a: user_a
    }
  end

  test "team :care can order for any resident; ordered_by_team_id set", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, view, _html} = live(conn, ~p"/kitchen/order/#{ctx.resident.id}")

    view
    |> element(
      "button[phx-click=order][phx-value-category=lunch]:not([phx-value-product_id=skip])"
    )
    |> render_click()

    orders =
      Kitchen.ResidentMealOrder
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert [order] = orders
    assert order.ordered_by_team_id == ctx.care_team.id
    assert is_nil(order.ordered_by_user_id)
    assert order.category == :lunch
    assert order.state == :ordered
  end

  test "relative user can order for own resident; ordered_by_user_id set", ctx do
    conn = sign_in_user(ctx.conn, ctx.user_a)
    {:ok, view, _html} = live(conn, ~p"/kitchen/order/#{ctx.resident.id}")

    view
    |> element(
      "button[phx-click=order][phx-value-category=lunch]:not([phx-value-product_id=skip])"
    )
    |> render_click()

    orders =
      Kitchen.ResidentMealOrder
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert [order] = orders
    assert order.ordered_by_user_id == ctx.user_a.id
    assert is_nil(order.ordered_by_team_id)
  end

  test "relative user cannot order for not-their resident", ctx do
    conn = sign_in_user(ctx.conn, ctx.user_a)
    {:ok, view, _html} = live(conn, ~p"/kitchen/order/#{ctx.other_resident.id}")

    html =
      view
      |> element(
        "button[phx-click=order][phx-value-category=lunch]:not([phx-value-product_id=skip])"
      )
      |> render_click()

    assert html =~ "You can&#39;t order for this resident."

    orders =
      Kitchen.ResidentMealOrder
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert orders == []
  end

  test "Skip destroys an existing order row", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, view, _html} = live(conn, ~p"/kitchen/order/#{ctx.resident.id}")

    view
    |> element(
      "button[phx-click=order][phx-value-category=lunch]:not([phx-value-product_id=skip])"
    )
    |> render_click()

    assert [_] =
             Kitchen.ResidentMealOrder
             |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    view
    |> element("button[phx-click=order][phx-value-category=lunch][phx-value-product_id=skip]")
    |> render_click()

    assert [] =
             Kitchen.ResidentMealOrder
             |> Ash.read!(tenant: ctx.facility.id, authorize?: false)
  end

  defp register_user(email) do
    user =
      Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          email: email,
          name: "RO",
          family_name: "User",
          password: "phase8-test-pass",
          password_confirmation: "phase8-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user
    |> Ash.Changeset.for_update(:update_profile, %{}, authorize?: false)
    |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
    |> Ash.update!(authorize?: false)
  end

  defp sign_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end
end
