defmodule CaredeckWeb.Services.NewRequestLiveTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Feed, Org, People, Services}

  require Ash.Query

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "NR #{suffix}", slug: "nr-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "NR Home", slug: "nr-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    care_team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-care-nr-#{suffix}",
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
        %{facility_id: facility.id, first_name: "Anna", last_name: "Becker"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    pharmacy =
      Services.ServiceProvider
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, kind: :pharmacy, name: "Apotheke"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    Feed.S3.ensure_bucket!()

    %{
      facility: facility,
      care_team: care_team,
      resident: resident,
      pharmacy: pharmacy
    }
  end

  test "team :care submits a pharmacy prescription_upload with photo", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, view, _html} = live(conn, ~p"/services/#{ctx.pharmacy.id}/new")

    img = <<0xFF, 0xD8, 0xFF, 0xE0>>

    upload =
      file_input(view, "form", :prescription, [
        %{name: "rx.jpg", content: img, type: "image/jpeg"}
      ])

    render_upload(upload, "rx.jpg")

    view
    |> form("form", %{
      "resident_id" => ctx.resident.id,
      "instructions" => "Take with food."
    })
    |> render_submit()

    request =
      Services.ServiceRequest
      |> Ash.Query.filter(provider_id == ^ctx.pharmacy.id)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert request.state == :open
    assert request.subkind == "prescription_upload"
    assert request.payload["instructions"] == "Take with food."
    assert request.payload["attachment_id"] != nil
    assert request.summary == "Prescription upload"

    [att] =
      Feed.Attachment
      |> Ash.Query.filter(service_request_id == ^request.id)
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert att.id == request.payload["attachment_id"]
    assert att.kind == :photo
  end

  test "team :care submits a pharmacy medication_inquiry (no upload)", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, view, _html} = live(conn, ~p"/services/#{ctx.pharmacy.id}/new")

    view |> element("button[phx-value-subkind=medication_inquiry]") |> render_click()

    view
    |> form("form", %{
      "resident_id" => ctx.resident.id,
      "medication_name" => "Aspirin",
      "question" => "Can it be split?"
    })
    |> render_submit()

    request =
      Services.ServiceRequest
      |> Ash.Query.filter(provider_id == ^ctx.pharmacy.id)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert request.subkind == "medication_inquiry"
    assert request.payload["medication_name"] == "Aspirin"
    assert request.payload["question"] == "Can it be split?"
    assert request.summary =~ "Aspirin"
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end
end
