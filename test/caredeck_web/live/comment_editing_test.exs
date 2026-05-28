defmodule CaredeckWeb.CommentEditingTest do
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
        %{name: "CE #{suffix}", slug: "ce-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "CE Home", slug: "ce-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    team = create_team(facility, suffix)
    user_a = create_user("ce-a-#{suffix}@example.test")
    user_b = create_user("ce-b-#{suffix}@example.test")
    create_membership(user_a, facility)
    create_membership(user_b, facility)

    post =
      Feed.Post
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          team_identity_id: team.id,
          body: "comment on me",
          is_internal: false
        },
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    comment =
      Feed.Comment
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          post_id: post.id,
          author_user_id: user_a.id,
          body: "first comment"
        },
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    %{
      facility: facility,
      team: team,
      user_a: user_a,
      user_b: user_b,
      post: post,
      comment: comment
    }
  end

  test "author sees Edit link on their own comment", ctx do
    conn = ctx.conn |> sign_in_user(ctx.user_a)
    {:ok, _view, html} = live(conn, ~p"/feed/#{ctx.post.id}")
    assert html =~ "Edit"
  end

  test "other relative does not see Edit link", ctx do
    conn = ctx.conn |> sign_in_user(ctx.user_b)
    {:ok, _view, html} = live(conn, ~p"/feed/#{ctx.post.id}")
    refute html =~ ">Edit</button>"
  end

  test "author can save edit", ctx do
    conn = ctx.conn |> sign_in_user(ctx.user_a)
    {:ok, view, _html} = live(conn, ~p"/feed/#{ctx.post.id}")

    view |> element("button[phx-click=edit_comment]") |> render_click()

    view
    |> form("form[phx-submit=save_comment]", %{
      "comment_id" => ctx.comment.id,
      "body" => "edited body"
    })
    |> render_submit()

    {:ok, reloaded} = Ash.get(Feed.Comment, ctx.comment.id, tenant: ctx.facility.id, authorize?: false)
    assert reloaded.body == "edited body"
    assert reloaded.edited_at != nil
  end

  test "edit after 5 minutes raises validation error at the Ash layer", ctx do
    old_comment = %{ctx.comment | inserted_at: DateTime.add(DateTime.utc_now(), -600, :second)}

    assert {:error, _err} =
             old_comment
             |> Ash.Changeset.for_update(:update, %{body: "too late"},
               tenant: ctx.facility.id,
               actor: ctx.user_a
             )
             |> Ash.update()
  end

  test "author can delete their own comment", ctx do
    conn = ctx.conn |> sign_in_user(ctx.user_a)
    {:ok, view, _html} = live(conn, ~p"/feed/#{ctx.post.id}")

    view |> element("button[phx-click=delete_comment]") |> render_click()

    rows = Feed.Comment |> Ash.read!(tenant: ctx.facility.id, authorize?: false)
    refute Enum.any?(rows, &(&1.id == ctx.comment.id))
  end

  defp create_team(facility, suffix) do
    Accounts.TeamIdentity
    |> Ash.Changeset.for_create(
      :register_with_password,
      %{
        handle: "team-ce-#{suffix}",
        name: "Team CE",
        role_kind: :care,
        facility_id: facility.id,
        password: "phase4-test-pass"
      },
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  defp create_user(email) do
    user =
      Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          email: email,
          name: "Test",
          family_name: "User",
          password: "phase4-test-pass",
          password_confirmation: "phase4-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user
    |> Ash.Changeset.for_update(:update_profile, %{}, authorize?: false)
    |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
    |> Ash.update!(authorize?: false)
  end

  defp create_membership(user, facility) do
    Org.FacilityMembership
    |> Ash.Changeset.for_create(
      :create,
      %{facility_id: facility.id, user_id: user.id, role: :relative, source: :manual},
      authorize?: false
    )
    |> Ash.create!(authorize?: false)

    People.Resident
  end

  defp sign_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)
  end
end
