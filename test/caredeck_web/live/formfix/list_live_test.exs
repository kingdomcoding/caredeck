defmodule CaredeckWeb.Formfix.ListLiveTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Formfix, Org, People}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "AL #{suffix}", slug: "al-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "AL Home", slug: "al-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    care_team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-care-al-#{suffix}",
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

    %{facility: facility, care_team: care_team, resident: resident, suffix: suffix}
  end

  test "care team sees an empty list initially", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, _view, html} = live(conn, ~p"/formfix")
    assert html =~ "Formfix"
    assert html =~ "No applications yet"
  end

  test "an existing application appears in the list", ctx do
    Formfix.Applications.start_for_resident!(ctx.facility, ctx.resident, ctx.care_team)
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, _view, html} = live(conn, ~p"/formfix")
    assert html =~ "Application for Anne Smith"
    assert html =~ "Draft"
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end
end
