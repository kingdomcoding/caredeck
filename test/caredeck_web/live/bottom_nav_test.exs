defmodule CaredeckWeb.BottomNavTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Org}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "BN #{suffix}", slug: "bn-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "BN Home", slug: "bn-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user = register_user("bn-#{suffix}@example.test")

    Org.FacilityMembership
    |> Ash.Changeset.for_create(
      :create,
      %{facility_id: facility.id, user_id: user.id, role: :relative, source: :manual},
      authorize?: false
    )
    |> Ash.create!(authorize?: false)

    %{facility: facility, user: user}
  end

  test "signed-in relative sees the bottom nav on /feed", ctx do
    conn = sign_in(ctx.conn, ctx.user)
    {:ok, _view, html} = live(conn, ~p"/feed")

    assert html =~ ~s(aria-label="Primary")
    assert html =~ "Home"
    assert html =~ "Profile"
    assert html =~ "Inbox"
    assert html =~ "Sign out"
  end

  test "anonymous user is redirected before nav renders", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/feed")
  end

  defp register_user(email) do
    user =
      Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          email: email,
          name: "BN",
          family_name: "User",
          password: "phase7-test-pass",
          password_confirmation: "phase7-test-pass"
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
