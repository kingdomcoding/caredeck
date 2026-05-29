defmodule CaredeckWeb.Services.HairdresserFeedTest do
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
        %{name: "HF #{suffix}", slug: "hf-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "HF Home", slug: "hf-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    care_team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-care-hf-#{suffix}",
          name: "Team Care",
          role_kind: :care,
          facility_id: facility.id,
          password: "phase9-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    hairdresser_team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-hairdresser-hf-#{suffix}",
          name: "Salon",
          role_kind: :service,
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

    hairdresser =
      Services.ServiceProvider
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          kind: :hairdresser,
          name: "Salon",
          team_identity_id: hairdresser_team.id
        },
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    %{
      facility: facility,
      care_team: care_team,
      hairdresser: hairdresser,
      hairdresser_team: hairdresser_team,
      resident: resident
    }
  end

  test "submits an appointment without posting to feed", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, view, _html} = live(conn, ~p"/services/#{ctx.hairdresser.id}/new")

    view
    |> form("form", %{
      "resident_id" => ctx.resident.id,
      "preferred_date" => "2026-06-12",
      "haircut_type" => "trim",
      "notes" => "Keep ears tidy."
    })
    |> render_submit()

    assert [request] =
             Services.ServiceRequest
             |> Ash.Query.filter(provider_id == ^ctx.hairdresser.id)
             |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert request.payload["post_to_feed"] == false

    assert [] =
             Feed.Post
             |> Ash.Query.filter(team_identity_id == ^ctx.hairdresser_team.id)
             |> Ash.read!(tenant: ctx.facility.id, authorize?: false)
  end

  test "submits an appointment with post_to_feed=true and creates a tagged Feed.Post", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, view, _html} = live(conn, ~p"/services/#{ctx.hairdresser.id}/new")

    view
    |> form("form", %{
      "resident_id" => ctx.resident.id,
      "preferred_date" => "2026-06-12",
      "haircut_type" => "trim",
      "notes" => "",
      "post_to_feed" => "true"
    })
    |> render_submit()

    [request] =
      Services.ServiceRequest
      |> Ash.Query.filter(provider_id == ^ctx.hairdresser.id)
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert request.payload["post_to_feed"] == true

    [post] =
      Feed.Post
      |> Ash.Query.filter(team_identity_id == ^ctx.hairdresser_team.id)
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert post.body =~ "Salon"
    assert post.body =~ "trim"

    assert [_] =
             Feed.ResidentTagOnPost
             |> Ash.Query.filter(post_id == ^post.id and resident_id == ^ctx.resident.id)
             |> Ash.read!(tenant: ctx.facility.id, authorize?: false)
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end
end
