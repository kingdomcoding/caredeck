defmodule CaredeckWeb.PostComposeLiveTest do
  use CaredeckWeb.ConnCase, async: false
  use Oban.Testing, repo: Caredeck.Repo

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Feed, Org, People}

  setup do
    Application.put_env(:caredeck, :thumbnailer_mode, :off)
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "PC #{suffix}", slug: "pc-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "PC Home", slug: "pc-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-pc-#{suffix}",
          name: "Team PC",
          role_kind: :care,
          facility_id: facility.id,
          password: "phase3-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user =
      Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          email: "pc-#{suffix}@example.test",
          name: "Test",
          family_name: "User",
          password: "phase3-test-pass",
          password_confirmation: "phase3-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user =
      user
      |> Ash.Changeset.for_update(:update_profile, %{}, authorize?: false)
      |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
      |> Ash.update!(authorize?: false)

    Org.FacilityMembership
    |> Ash.Changeset.for_create(
      :create,
      %{facility_id: facility.id, user_id: user.id, role: :relative, source: :manual},
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
      |> Ash.create!(tenant: facility.id, authorize?: false)

    %{facility: facility, team: team, user: user, resident: resident}
  end

  test "team can open /feed/compose", ctx do
    conn = ctx.conn |> sign_in_team(ctx.team)
    {:ok, _view, html} = live(conn, ~p"/feed/compose")
    assert html =~ "New post"
    assert html =~ "All residents"
  end

  test "user (no team) is redirected away from /feed/compose", ctx do
    conn = ctx.conn |> sign_in_user(ctx.user)

    {:error, {:redirect, %{to: redirect_to}}} = live(conn, ~p"/feed/compose")
    assert redirect_to == "/team/sign-in"
  end

  test "sending creates a Post + PostAudience rows", ctx do
    conn = ctx.conn |> sign_in_team(ctx.team)
    {:ok, view, _html} = live(conn, ~p"/feed/compose")

    view |> element("button[phx-click=toggle_audience]") |> render_click()

    view
    |> form("#compose-form", %{"body" => "Hello world"})
    |> render_submit()

    posts =
      Feed.Post
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert Enum.any?(posts, &(&1.body == "Hello world"))

    audience =
      Feed.PostAudience
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert audience != []
  end

  test "sending enqueues a post_created fanout job after audience sync", ctx do
    conn = ctx.conn |> sign_in_team(ctx.team)
    {:ok, view, _html} = live(conn, ~p"/feed/compose")

    view |> element("button[phx-click=toggle_audience]") |> render_click()

    view
    |> form("#compose-form", %{"body" => "Fan me out"})
    |> render_submit()

    post =
      Feed.Post
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)
      |> Enum.find(&(&1.body == "Fan me out"))

    assert_enqueued(
      worker: Caredeck.Workers.NotificationFanout,
      args: %{event: "post_created", post_id: post.id, facility_id: ctx.facility.id}
    )
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end

  defp sign_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)
  end
end
