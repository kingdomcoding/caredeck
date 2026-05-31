defmodule CaredeckWeb.PageControllerTest do
  use CaredeckWeb.ConnCase

  alias Caredeck.{Accounts, Org}

  describe "GET /" do
    test "unsigned visitor is redirected to /sign-in", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert redirected_to(conn) == ~p"/sign-in"
    end

    test "signed-in user is redirected to /feed", %{conn: conn} do
      suffix = :erlang.unique_integer([:positive])

      user =
        Accounts.User
        |> Ash.Changeset.for_create(
          :register_with_password,
          %{
            email: "root-test-#{suffix}@example.test",
            password: "root-test-pass",
            password_confirmation: "root-test-pass"
          },
          authorize?: false
        )
        |> Ash.create!(authorize?: false)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)
        |> get(~p"/")

      assert redirected_to(conn) == ~p"/feed"
    end

    test "signed-in team is redirected to /feed", %{conn: conn} do
      suffix = :erlang.unique_integer([:positive])

      district =
        Org.District
        |> Ash.Changeset.for_create(
          :create,
          %{name: "Root #{suffix}", slug: "root-#{suffix}"},
          authorize?: false
        )
        |> Ash.create!(authorize?: false)

      facility =
        Org.Facility
        |> Ash.Changeset.for_create(
          :create,
          %{district_id: district.id, name: "Root Home", slug: "root-home-#{suffix}"},
          authorize?: false
        )
        |> Ash.create!(authorize?: false)

      team =
        Accounts.TeamIdentity
        |> Ash.Changeset.for_create(
          :register_with_password,
          %{
            handle: "root-team-#{suffix}",
            name: "Root Team",
            role_kind: :care,
            facility_id: facility.id,
            password: "root-test-pass"
          },
          authorize?: false
        )
        |> Ash.create!(authorize?: false)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(team)
        |> get(~p"/")

      assert redirected_to(conn) == ~p"/feed"
    end
  end
end
