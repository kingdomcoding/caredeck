defmodule CaredeckWeb.NotificationsLiveTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Org}
  alias Caredeck.Notifications.Notification
  alias CaredeckWeb.Endpoint

  require Ash.Query

  setup do
    Application.put_env(:caredeck, :thumbnailer_mode, :off)
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "NLT #{suffix}", slug: "nlt-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "NLT Home", slug: "nlt-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user = register_user("nlt-#{suffix}@example.test")

    Org.FacilityMembership
    |> Ash.Changeset.for_create(
      :create,
      %{facility_id: facility.id, user_id: user.id, role: :relative, source: :manual},
      authorize?: false
    )
    |> Ash.create!(authorize?: false)

    actor_id = Ash.UUID.generate()

    older =
      create_notification(facility, user, %{
        actor_id: actor_id,
        verb: :commented,
        target_id: Ash.UUID.generate()
      })

    Process.sleep(10)

    newer =
      create_notification(facility, user, %{
        actor_id: actor_id,
        verb: :liked,
        target_id: Ash.UUID.generate()
      })

    %{facility: facility, user: user, older: older, newer: newer}
  end

  test "anonymous user is redirected", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/notifications")
  end

  test "signed-in user sees notifications in descending order", ctx do
    conn = sign_in(ctx.conn, ctx.user)
    {:ok, view, _html} = live(conn, ~p"/notifications")

    html = render(view)
    older_pos = :binary.match(html, ctx.older.id)
    newer_pos = :binary.match(html, ctx.newer.id)

    assert is_tuple(newer_pos)
    assert is_tuple(older_pos)
    {newer_index, _} = newer_pos
    {older_index, _} = older_pos
    assert newer_index < older_index
  end

  test "mark_all_read clears every unread row", ctx do
    conn = sign_in(ctx.conn, ctx.user)
    {:ok, view, _html} = live(conn, ~p"/notifications")

    view |> element("button", "Mark all read") |> render_click()

    unread_after =
      Notification
      |> Ash.Query.filter(user_id == ^ctx.user.id and is_nil(read_at))
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert unread_after == []
    refute render(view) =~ "Mark all read"
  end

  test "clicking a notification row marks it read and navigates to its target", ctx do
    conn = sign_in(ctx.conn, ctx.user)
    {:ok, view, _html} = live(conn, ~p"/notifications")

    assert {:error, {:live_redirect, %{to: target}}} =
             view
             |> element("li[phx-value-id='#{ctx.newer.id}']")
             |> render_click()

    assert target == "/feed/#{ctx.newer.target_id}"

    reloaded =
      Ash.get!(Notification, ctx.newer.id, tenant: ctx.facility.id, authorize?: false)

    refute is_nil(reloaded.read_at)
  end

  test "broadcasting a notification_created event re-renders the list", ctx do
    conn = sign_in(ctx.conn, ctx.user)
    {:ok, view, _html} = live(conn, ~p"/notifications")

    fresh =
      create_notification(ctx.facility, ctx.user, %{
        actor_id: Ash.UUID.generate(),
        verb: :posted,
        target_id: Ash.UUID.generate()
      })

    Endpoint.broadcast(
      "user:#{ctx.user.id}:notifications",
      "notification_created",
      %{id: fresh.id}
    )

    html = render(view)
    assert html =~ fresh.id
  end

  defp create_notification(facility, user, attrs) do
    base = %{
      facility_id: facility.id,
      user_id: user.id,
      actor_kind: :user,
      target_kind: :post
    }

    Notification
    |> Ash.Changeset.for_create(:create, Map.merge(base, attrs),
      tenant: facility.id,
      authorize?: false
    )
    |> Ash.create!(tenant: facility.id, authorize?: false)
  end

  defp register_user(email) do
    user =
      Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          email: email,
          name: "Notif",
          family_name: "User",
          password: "phase6-test-pass",
          password_confirmation: "phase6-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user
    |> Ash.Changeset.for_update(:update_profile, %{}, authorize?: false)
    |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
    |> Ash.update!(authorize?: false)
  end

  defp sign_in(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)
  end
end
