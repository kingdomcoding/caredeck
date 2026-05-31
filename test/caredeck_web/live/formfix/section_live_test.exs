defmodule CaredeckWeb.Formfix.SectionLiveTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Formfix, Org, People}

  require Ash.Query

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "SL #{suffix}", slug: "sl-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "SL Home", slug: "sl-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    care_team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-care-sl-#{suffix}",
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

    application = Formfix.Applications.start_for_resident!(facility, resident, care_team)

    %{facility: facility, care_team: care_team, resident: resident, application: application}
  end

  test "rendering person_needing_care shows the labels + rationale", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)

    {:ok, _view, html} =
      live(conn, ~p"/formfix/#{ctx.application.id}/section/person_needing_care")

    assert html =~ "Person Needing Care"
    assert html =~ "First name"
    assert html =~ "Marital status"
    assert html =~ "affects various welfare-law questions"
  end

  test "filling all required fields flips section status to :complete", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)

    {:ok, view, _html} =
      live(conn, ~p"/formfix/#{ctx.application.id}/section/person_needing_care")

    view
    |> form("form", %{
      "first_name" => "Anne",
      "last_name" => "Smith",
      "date_of_birth" => "1942-03-15",
      "marital_status" => "widowed",
      "postal_code" => "12345",
      "street" => "1 Main",
      "city" => "Townsville"
    })
    |> render_submit()

    section =
      Formfix.ApplicationSection
      |> Ash.Query.filter(
        application_id == ^ctx.application.id and section_key == :person_needing_care
      )
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert section.status == :complete
  end

  test "Skip button transitions a form section to :skipped", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, view, _html} = live(conn, ~p"/formfix/#{ctx.application.id}/section/applicant")

    view |> element("button[phx-click=skip]") |> render_click()

    section =
      Formfix.ApplicationSection
      |> Ash.Query.filter(application_id == ^ctx.application.id and section_key == :applicant)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert section.status == :skipped
  end

  test "Welcome shows Begin button (no Skip) and transitions welcome to :complete", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, view, html} = live(conn, ~p"/formfix/#{ctx.application.id}/section/welcome")

    refute html =~ "phx-click=\"skip\""
    assert html =~ "Begin"

    view |> element("button[phx-click=begin]") |> render_click()

    section =
      Formfix.ApplicationSection
      |> Ash.Query.filter(application_id == ^ctx.application.id and section_key == :welcome)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert section.status == :complete
  end

  test "navigating to a non-materialised section redirects to overview", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)

    assert {:error, {:live_redirect, %{to: redirect}}} =
             live(conn, ~p"/formfix/#{ctx.application.id}/section/income_partner")

    assert redirect == "/formfix/#{ctx.application.id}/overview"
  end

  test "care level select rejects values outside 1..5 via the parse layer", _ctx do
    assert Caredeck.Formfix.SectionSchema.parse({:integer_select, [1, 2, 3, 4, 5]}, "3") ==
             {:ok, 3}

    assert Caredeck.Formfix.SectionSchema.parse({:integer_select, [1, 2, 3, 4, 5]}, "6") ==
             :error

    assert Caredeck.Formfix.SectionSchema.parse({:integer_select, [1, 2, 3, 4, 5]}, "abc") ==
             :error
  end

  test "required boolean renders as Yes/No radios (not a single checkbox)", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, _view, html} = live(conn, ~p"/formfix/#{ctx.application.id}/section/disability")

    assert html =~ ~s(type="radio")
    assert html =~ ~s(value="true")
    assert html =~ ~s(value="false")
    assert html =~ ">Yes</span>"
    assert html =~ ">No</span>"
  end

  test "show_when field is hidden until its trigger flips true", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, view, html} = live(conn, ~p"/formfix/#{ctx.application.id}/section/disability")

    refute html =~ "Degree (%)"

    view
    |> element("form")
    |> render_change(%{"has_disability_status" => "true"})

    html_after = render(view)
    assert html_after =~ "Degree (%)"
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end
end
