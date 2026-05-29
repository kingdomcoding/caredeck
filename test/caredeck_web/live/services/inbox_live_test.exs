defmodule CaredeckWeb.Services.InboxLiveTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Org, People, Services}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "INB #{suffix}", slug: "inb-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "INB Home", slug: "inb-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    care_team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-care-inb-#{suffix}",
          name: "Team Care",
          role_kind: :care,
          facility_id: facility.id,
          password: "phase9-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    kitchen_team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-kitchen-inb-#{suffix}",
          name: "Team Kitchen",
          role_kind: :kitchen,
          facility_id: facility.id,
          password: "phase9-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    resident =
      People.Resident
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, first_name: "A", last_name: "B"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    pharmacy =
      Services.ServiceProvider
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, kind: :pharmacy, name: "Pharmacy"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    Services.ServiceRequest
    |> Ash.Changeset.for_create(
      :create,
      %{
        facility_id: facility.id,
        provider_id: pharmacy.id,
        resident_id: resident.id,
        subkind: "general_question",
        summary: "Open one",
        payload: %{"subkind" => "general_question", "question" => "?"}
      },
      tenant: facility.id,
      authorize?: false
    )
    |> Ash.create!(tenant: facility.id, authorize?: false)

    %{facility: facility, care_team: care_team, kitchen_team: kitchen_team}
  end

  test "/services/inbox shows open requests for care team", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, _view, html} = live(conn, ~p"/services/inbox")

    assert html =~ "Services inbox"
    assert html =~ "Open one"
    assert html =~ "Pharmacy"
  end

  test "/services/inbox redirects non-care/non-service teams", ctx do
    conn = sign_in_team(ctx.conn, ctx.kitchen_team)
    assert {:error, {:live_redirect, %{to: "/services"}}} = live(conn, ~p"/services/inbox")
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end
end
