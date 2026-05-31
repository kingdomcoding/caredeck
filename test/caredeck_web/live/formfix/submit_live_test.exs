defmodule CaredeckWeb.Formfix.SubmitLiveTest do
  use CaredeckWeb.ConnCase, async: false
  use Oban.Testing, repo: Caredeck.Repo

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Formfix, Org, People}

  require Ash.Query

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "SS #{suffix}", slug: "ss-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "SS Home", slug: "ss-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    care_team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-care-ss-#{suffix}",
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

  test "submit button disabled when application is still :draft", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, _view, html} = live(conn, ~p"/formfix/#{ctx.application.id}/submit")

    assert html =~ "Submit application"
    assert html =~ "disabled"
    assert html =~ "Please complete all sections"
  end

  test "submit transitions to :submitted when application is :ready_to_submit", ctx do
    # Force state to ready_to_submit by skipping every section
    Caredeck.Formfix.ApplicationSection
    |> Ash.Query.filter(application_id == ^ctx.application.id)
    |> Ash.read!(tenant: ctx.facility.id, authorize?: false)
    |> Enum.each(fn s ->
      s
      |> Ash.Changeset.for_update(:transition, %{status: :skipped},
        tenant: ctx.facility.id,
        authorize?: false
      )
      |> Ash.update!(tenant: ctx.facility.id, authorize?: false)
    end)

    # Recompute → should flip to ready_to_submit (no documents required for skipped sections)
    app =
      Ash.get!(Formfix.Application, ctx.application.id,
        tenant: ctx.facility.id,
        authorize?: false
      )

    :ok = Formfix.Applications.recompute_status(app)

    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, view, _html} = live(conn, ~p"/formfix/#{ctx.application.id}/submit")

    view |> element("button[phx-click=submit]") |> render_click()

    updated =
      Ash.get!(Formfix.Application, ctx.application.id,
        tenant: ctx.facility.id,
        authorize?: false
      )

    assert updated.state == :submitted
    assert updated.submitted_at != nil
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end
end
