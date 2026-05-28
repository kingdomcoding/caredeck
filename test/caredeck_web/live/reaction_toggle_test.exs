defmodule CaredeckWeb.ReactionToggleTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Feed, Org, People}

  setup do
    Application.put_env(:caredeck, :thumbnailer_mode, :off)
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "RT #{suffix}", slug: "rt-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "RT Home", slug: "rt-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-rt-#{suffix}",
          name: "Team RT",
          role_kind: :care,
          facility_id: facility.id,
          password: "phase4-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user =
      Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          email: "rt-#{suffix}@example.test",
          name: "RT",
          family_name: "Tester",
          password: "phase4-test-pass",
          password_confirmation: "phase4-test-pass"
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

    post =
      Feed.Post
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, team_identity_id: team.id, body: "react to me"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    %{facility: facility, team: team, user: user, post: post, resident: resident}
  end

  test "Reaction.toggle adds a reaction when none exists, removes when present", ctx do
    {:ok, %{action: :added}} =
      Feed.Reaction
      |> Ash.ActionInput.for_action(
        :toggle,
        %{facility_id: ctx.facility.id, post_id: ctx.post.id},
        actor: ctx.user,
        tenant: ctx.facility.id
      )
      |> Ash.run_action()

    {:ok, %{action: :removed}} =
      Feed.Reaction
      |> Ash.ActionInput.for_action(
        :toggle,
        %{facility_id: ctx.facility.id, post_id: ctx.post.id},
        actor: ctx.user,
        tenant: ctx.facility.id
      )
      |> Ash.run_action()
  end

  test "clicking heart on /feed creates a Reaction row", ctx do
    conn = ctx.conn |> sign_in_user(ctx.user)
    {:ok, view, _html} = live(conn, ~p"/feed")

    view |> element("button[phx-click=toggle_reaction]") |> render_click()

    reactions =
      Feed.Reaction
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert Enum.any?(reactions, &(&1.user_id == ctx.user.id and &1.post_id == ctx.post.id))
  end

  defp sign_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)
  end
end
