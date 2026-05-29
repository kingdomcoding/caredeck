defmodule CaredeckWeb.Aid.OverviewLiveTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Aid, Org, People}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "AO #{suffix}", slug: "ao-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "AO Home", slug: "ao-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    care_team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-care-ao-#{suffix}",
          name: "Team Care",
          role_kind: :care,
          facility_id: facility.id,
          password: "phase10-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    resident =
      People.Resident
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, first_name: "Anne", last_name: "Smith"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    application = Aid.Applications.start_for_resident!(facility, resident, care_team)

    %{facility: facility, care_team: care_team, resident: resident, application: application}
  end

  test "renders 13 section tiles and the support card", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, _view, html} = live(conn, ~p"/aid/#{ctx.application.id}/overview")

    assert html =~ "Welcome"
    assert html =~ "Person Needing Care"
    assert html =~ "Applicant"
    assert html =~ "Care Situation"
    assert html =~ "Income"
    assert html =~ "Assets"
    assert html =~ "Expenses"
    assert html =~ "Disability"
    assert html =~ "Foreign-Nationality Status"
    assert html =~ "Demo Caseworker"
    assert html =~ "Support: Mon–Fri 9 am – 5 pm"
    assert html =~ "Your data is safe with us"
  end

  test "renders progress bar at 0% initially", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, _view, html} = live(conn, ~p"/aid/#{ctx.application.id}/overview")
    assert html =~ "0% complete"
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end
end
