defmodule CaredeckWeb.Services.LaundryComplaintTest do
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
        %{name: "LC #{suffix}", slug: "lc-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "LC Home", slug: "lc-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    care_team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-care-lc-#{suffix}",
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

    laundry =
      Services.ServiceProvider
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, kind: :laundry, name: "Linen"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    Feed.S3.ensure_bucket!()

    %{
      facility: facility,
      care_team: care_team,
      resident: resident,
      laundry: laundry
    }
  end

  test "team :care submits a laundry complaint with required photo", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, view, _html} = live(conn, ~p"/services/#{ctx.laundry.id}/new")

    img = <<0xFF, 0xD8, 0xFF, 0xE0>>

    upload =
      file_input(view, "form", :laundry_photo, [
        %{name: "stain.jpg", content: img, type: "image/jpeg"}
      ])

    render_upload(upload, "stain.jpg")

    view
    |> form("form", %{
      "resident_id" => ctx.resident.id,
      "reason" => "Item shrunk",
      "details" => "Shirt no longer fits."
    })
    |> render_submit()

    request =
      Services.ServiceRequest
      |> Ash.Query.filter(provider_id == ^ctx.laundry.id)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert request.subkind == "complaint"
    assert request.payload["reason"] == "Item shrunk"
    assert request.payload["details"] == "Shirt no longer fits."
    assert request.payload["attachment_id"] != nil
    assert request.summary == "Laundry complaint — Item shrunk"

    [att] =
      Feed.Attachment
      |> Ash.Query.filter(service_request_id == ^request.id)
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert att.id == request.payload["attachment_id"]
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end
end
