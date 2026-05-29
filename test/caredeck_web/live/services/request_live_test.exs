defmodule CaredeckWeb.Services.RequestLiveTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Org, People, Services}

  require Ash.Query

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "RL #{suffix}", slug: "rl-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "RL Home", slug: "rl-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    care_team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-care-rl-#{suffix}",
          name: "Team Care",
          role_kind: :care,
          facility_id: facility.id,
          password: "phase9-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    pharmacy_team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-pharmacy-rl-#{suffix}",
          name: "Pharmacy",
          role_kind: :service,
          facility_id: facility.id,
          password: "phase9-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user =
      Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          email: "rl-user-#{suffix}@example.test",
          name: "RL",
          family_name: "User",
          password: "phase9-test-pass",
          password_confirmation: "phase9-test-pass"
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
        %{facility_id: facility.id, first_name: "Anna", last_name: "Smith"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    relative =
      People.Relative
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, user_id: user.id, display_name: "RL User"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    People.RelativeOfResident
    |> Ash.Changeset.for_create(
      :create,
      %{
        facility_id: facility.id,
        relative_id: relative.id,
        resident_id: resident.id,
        relationship: :daughter
      },
      tenant: facility.id,
      authorize?: false
    )
    |> Ash.create!(tenant: facility.id, authorize?: false)

    pharmacy =
      Services.ServiceProvider
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          kind: :pharmacy,
          name: "Pharmacy",
          team_identity_id: pharmacy_team.id
        },
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    request =
      Services.ServiceRequest
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          provider_id: pharmacy.id,
          resident_id: resident.id,
          requester_user_id: user.id,
          subkind: "general_question",
          summary: "Question for pharmacy",
          payload: %{"subkind" => "general_question", "question" => "Available Friday?"}
        },
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    %{
      facility: facility,
      care_team: care_team,
      pharmacy_team: pharmacy_team,
      user: user,
      request: request
    }
  end

  test "provider team can read the request and reply", ctx do
    conn = sign_in_team(ctx.conn, ctx.pharmacy_team)
    {:ok, view, html} = live(conn, ~p"/services/requests/#{ctx.request.id}")

    assert html =~ "Question for pharmacy"
    assert html =~ "Pharmacy"

    view
    |> form("form[phx-submit=send]", %{"body" => "Yes — Friday morning."})
    |> render_submit()

    messages =
      Services.ServiceMessage
      |> Ash.Query.filter(service_request_id == ^ctx.request.id)
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert [%{body: "Yes — Friday morning.", author_team_id: tid}] = messages
    assert tid == ctx.pharmacy_team.id
  end

  test "care team can resolve a request and resolved_at is stamped", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, view, _} = live(conn, ~p"/services/requests/#{ctx.request.id}")

    view |> element("button[phx-value-to=resolved]") |> render_click()

    {:ok, after_resolve} =
      Ash.get(Services.ServiceRequest, ctx.request.id,
        tenant: ctx.facility.id,
        authorize?: false
      )

    assert after_resolve.state == :resolved
    assert after_resolve.resolved_at != nil
  end

  test "relative does not see transition buttons but can post a message", ctx do
    conn = sign_in_user(ctx.conn, ctx.user)
    {:ok, view, html} = live(conn, ~p"/services/requests/#{ctx.request.id}")

    refute html =~ ~s(phx-value-to="resolved")

    view
    |> form("form[phx-submit=send]", %{"body" => "Thank you!"})
    |> render_submit()

    [message] =
      Services.ServiceMessage
      |> Ash.Query.filter(service_request_id == ^ctx.request.id)
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert message.body == "Thank you!"
    assert message.author_user_id == ctx.user.id
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end

  defp sign_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)
  end
end
