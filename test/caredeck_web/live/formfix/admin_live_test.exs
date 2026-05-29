defmodule CaredeckWeb.Formfix.AdminLiveTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Formfix, Org, People}

  require Ash.Query

  setup do
    suffix = :erlang.unique_integer([:positive])

    district = create_district(suffix)
    fac_a = create_facility(district, "A", "admin-a-#{suffix}")
    fac_b = create_facility(district, "B", "admin-b-#{suffix}")

    admin_a = create_team(fac_a, "team-admin-a-#{suffix}", :admin)
    care_a = create_team(fac_a, "team-care-a-#{suffix}", :care)
    admin_b = create_team(fac_b, "team-admin-b-#{suffix}", :admin)
    care_b = create_team(fac_b, "team-care-b-#{suffix}", :care)

    resident_a = create_resident(fac_a, "Anne", "Smith")
    resident_b = create_resident(fac_b, "Beth", "Jones")

    app_a = Formfix.Applications.start_for_resident!(fac_a, resident_a, care_a)
    app_b = Formfix.Applications.start_for_resident!(fac_b, resident_b, care_b)

    %{
      facility_a: fac_a,
      facility_b: fac_b,
      admin_a: admin_a,
      care_a: care_a,
      admin_b: admin_b,
      app_a: app_a,
      app_b: app_b
    }
  end

  test "non-admin team is redirected to /", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_a)

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/formfix/admin")
  end

  test "admin sees only their own facility's applications", ctx do
    conn = sign_in_team(ctx.conn, ctx.admin_a)
    {:ok, _view, html} = live(conn, ~p"/formfix/admin")

    assert html =~ "Anne Smith"
    refute html =~ "Beth Jones"
  end

  test "add-note creates a row and renders inline", ctx do
    conn = sign_in_team(ctx.conn, ctx.admin_a)
    {:ok, view, _html} = live(conn, ~p"/formfix/admin")

    view
    |> render_submit("add-note", %{"app_id" => ctx.app_a.id, "body" => "Looking great"})

    after_html = render(view)
    assert after_html =~ "Looking great"

    notes =
      Formfix.ApplicationNote
      |> Ash.Query.filter(application_id == ^ctx.app_a.id)
      |> Ash.read!(tenant: ctx.facility_a.id, authorize?: false)

    assert length(notes) == 1
  end

  test "empty body submit is a no-op", ctx do
    conn = sign_in_team(ctx.conn, ctx.admin_a)
    {:ok, view, _html} = live(conn, ~p"/formfix/admin")

    view
    |> render_submit("add-note", %{"app_id" => ctx.app_a.id, "body" => "   "})

    notes =
      Formfix.ApplicationNote
      |> Ash.Query.filter(application_id == ^ctx.app_a.id)
      |> Ash.read!(tenant: ctx.facility_a.id, authorize?: false)

    assert notes == []
  end

  defp create_district(suffix) do
    Org.District
    |> Ash.Changeset.for_create(
      :create,
      %{name: "Admin #{suffix}", slug: "admin-#{suffix}"},
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

  defp create_team(fac, handle, role_kind) do
    Accounts.TeamIdentity
    |> Ash.Changeset.for_create(
      :register_with_password,
      %{
        handle: handle,
        name: "T #{handle}",
        role_kind: role_kind,
        facility_id: fac.id,
        password: "phase11-test-pass"
      },
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

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end
end
