defmodule CaredeckWeb.DemoSignInControllerTest do
  use CaredeckWeb.ConnCase

  alias Caredeck.{Accounts, Org}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "Demo #{suffix}", slug: "demo-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "Demo Home", slug: "demo-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    %{facility: facility}
  end

  describe "with seeded demo accounts" do
    setup ctx do
      _admin = create_team(ctx.facility, "team-admin", :admin)
      _care = create_team(ctx.facility, "team-care", :care)
      _user = create_user("demo-relative@example.test")
      :ok
    end

    test "POST /demo/admin redirects to /formfix/admin with team session", %{conn: conn} do
      conn = post(conn, ~p"/demo/admin")
      assert redirected_to(conn) == ~p"/formfix/admin"

      assert Enum.any?(get_session(conn), fn {k, v} ->
               String.contains?(to_string(k), "team") and is_binary(v)
             end)
    end

    test "POST /demo/care redirects to /feed", %{conn: conn} do
      conn = post(conn, ~p"/demo/care")
      assert redirected_to(conn) == ~p"/feed"
    end

    test "POST /demo/relative redirects to /feed", %{conn: conn} do
      conn = post(conn, ~p"/demo/relative")
      assert redirected_to(conn) == ~p"/feed"
    end
  end

  describe "without seeded demo accounts" do
    test "POST /demo/admin flashes + redirects to /sign-in", %{conn: conn} do
      conn = post(conn, ~p"/demo/admin")
      assert redirected_to(conn) == ~p"/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not seeded"
    end
  end

  defp create_team(fac, handle, role_kind) do
    Accounts.TeamIdentity
    |> Ash.Changeset.for_create(
      :register_with_password,
      %{
        handle: handle,
        name: "T #{handle}",
        role_kind: role_kind,
        facility_id: fac.id,
        password: "demo-test-pass"
      },
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  defp create_user(email) do
    Accounts.User
    |> Ash.Changeset.for_create(
      :register_with_password,
      %{
        email: email,
        password: "demo-test-pass",
        password_confirmation: "demo-test-pass"
      },
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end
end
