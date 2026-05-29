defmodule CaredeckWeb.Services.IndexLiveTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Org, Services}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "SVC IDX #{suffix}", slug: "svci-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "SVC Home", slug: "svci-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    care_team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-care-svci-#{suffix}",
          name: "Team Care",
          role_kind: :care,
          facility_id: facility.id,
          password: "phase9-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    for {kind, name} <- [
          {:pharmacy, "Pharmacy"},
          {:laundry, "Linen"},
          {:hairdresser, "Salon"}
        ] do
      Services.ServiceProvider
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, kind: kind, name: name},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)
    end

    %{facility: facility, care_team: care_team}
  end

  test "/services shows all seeded providers for a care team", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, _view, html} = live(conn, ~p"/services")

    assert html =~ "Services"
    assert html =~ "Pharmacy"
    assert html =~ "Linen"
    assert html =~ "Salon"
    assert html =~ "Pharmacy"
    assert html =~ "Laundry"
    assert html =~ "Hairdresser"
  end

  test "redirects an unauthenticated conn to sign-in", ctx do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(ctx.conn, ~p"/services")
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end
end
