defmodule CaredeckWeb.FeedLiveTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Feed, Org}

  setup do
    Application.put_env(:caredeck, :thumbnailer_mode, :off)
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "FL #{suffix}", slug: "fl-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "FL Home", slug: "fl-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-fl-#{suffix}",
          name: "Team Feed",
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
          email: "fl-#{suffix}@example.test",
          name: "Feed",
          family_name: "Tester",
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

    post =
      Feed.Post
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, team_identity_id: team.id, body: "hello feed"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    %{facility: facility, user: user, team: team, post: post}
  end

  test "anonymous request to /feed redirects to /sign-in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/feed")
  end

  test "signed-in user sees their facility's feed", %{conn: conn} = ctx do
    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> AshAuthentication.Plug.Helpers.store_in_session(ctx.user)

    {:ok, _view, html} = live(conn, ~p"/feed")
    assert html =~ "hello feed"
    assert html =~ "Team Feed"
  end
end
