defmodule CaredeckWeb.AudienceTagsPopoverTest do
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
        %{name: "ATP #{suffix}", slug: "atp-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "ATP Home", slug: "atp-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    team = create_team(facility, suffix)
    user = create_user("atp-#{suffix}@example.test")
    create_membership(user, facility)

    [r1, r2, r3] =
      Enum.map(["Anna Becker", "Otto Berger", "Lena Meyer"], fn full ->
        [first, last] = String.split(full, " ")

        People.Resident
        |> Ash.Changeset.for_create(
          :create,
          %{facility_id: facility.id, first_name: first, last_name: last},
          tenant: facility.id,
          authorize?: false
        )
        |> Ash.create!(tenant: facility.id, authorize?: false)
      end)

    post =
      Feed.Post
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, team_identity_id: team.id, body: "tagged"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    Enum.each([r1, r2, r3], fn r ->
      Feed.PostAudience
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, post_id: post.id, resident_id: r.id},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

      Feed.ResidentTagOnPost
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, post_id: post.id, resident_id: r.id},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)
    end)

    %{facility: facility, team: team, user: user, post: post, residents: [r1, r2, r3]}
  end

  test "Tags pool empty before audience selected, populated after", ctx do
    conn = ctx.conn |> sign_in_team(ctx.team)
    {:ok, view, html} = live(conn, ~p"/feed/compose")
    assert html =~ "Add residents to the audience first"

    view |> element("button[phx-click=toggle_all_audience]") |> render_click()

    rendered = render(view)
    refute rendered =~ "Add residents to the audience first"

    Enum.each(ctx.residents, fn r ->
      assert rendered =~ "#{r.first_name} #{r.last_name}"
    end)
  end

  test "untagging via toggle_tag keeps resident in audience", ctx do
    conn = ctx.conn |> sign_in_team(ctx.team)
    {:ok, view, _html} = live(conn, ~p"/feed/compose")

    view |> element("button[phx-click=toggle_all_audience]") |> render_click()

    target = hd(ctx.residents)
    selector = ~s|button[phx-click="toggle_tag"][phx-value-id="#{target.id}"]|

    view |> element(selector) |> render_click()

    rendered = render(view)
    assert rendered =~ "#{target.first_name} #{target.last_name}"
  end

  test "tag popover opens on click", ctx do
    conn = ctx.conn |> sign_in_user(ctx.user)
    {:ok, view, html} = live(conn, ~p"/feed")

    refute html =~ "Tagged residents"

    view |> element("button[phx-click=toggle_tag_popover]") |> render_click()
    rendered = render(view)

    assert rendered =~ "Tagged residents"
    assert rendered =~ "Anna Becker"
  end

  defp create_team(facility, suffix) do
    Accounts.TeamIdentity
    |> Ash.Changeset.for_create(
      :register_with_password,
      %{
        handle: "team-atp-#{suffix}",
        name: "Team ATP",
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
