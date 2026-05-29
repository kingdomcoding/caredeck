defmodule CaredeckWeb.Services.DoctorRequestTest do
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
        %{name: "DR #{suffix}", slug: "dr-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "DR Home", slug: "dr-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    care_team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-care-dr-#{suffix}",
          name: "Team Care",
          role_kind: :care,
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
        %{facility_id: facility.id, first_name: "Anna", last_name: "Smith"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    doctor =
      Services.ServiceProvider
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, kind: :doctor, name: "GP"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    %{facility: facility, care_team: care_team, resident: resident, doctor: doctor}
  end

  test "doctor appointment_request form does not show haircut radios", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, _view, html} = live(conn, ~p"/services/#{ctx.doctor.id}/new")

    refute html =~ "Haircut type"
    refute html =~ ~s(name="haircut_type")
    refute html =~ "Also post to family feed"

    assert html =~ "Preferred date"
    assert html =~ "Describe what the appointment is for"
  end

  test "doctor appointment_request submits with preferred_date + details", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, view, _html} = live(conn, ~p"/services/#{ctx.doctor.id}/new")

    view
    |> form("form", %{
      "resident_id" => ctx.resident.id,
      "preferred_date" => "2026-07-01",
      "details" => "Routine check-up."
    })
    |> render_submit()

    request =
      Services.ServiceRequest
      |> Ash.Query.filter(provider_id == ^ctx.doctor.id)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert request.subkind == "appointment_request"
    assert request.payload["details"] == "Routine check-up."
    assert request.payload["preferred_date"] == "2026-07-01"
    refute Map.has_key?(request.payload, "haircut_type")
    assert request.summary =~ "Doctor"
  end

  test "doctor information_request submits with details only", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, view, _html} = live(conn, ~p"/services/#{ctx.doctor.id}/new")

    view |> element("button[phx-value-subkind=information_request]") |> render_click()

    view
    |> form("form", %{
      "resident_id" => ctx.resident.id,
      "details" => "Vaccination schedule please."
    })
    |> render_submit()

    request =
      Services.ServiceRequest
      |> Ash.Query.filter(provider_id == ^ctx.doctor.id)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert request.subkind == "information_request"
    assert request.payload["details"] == "Vaccination schedule please."
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end
end
