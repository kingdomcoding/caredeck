defmodule CaredeckWeb.AttachmentControllerTest do
  use CaredeckWeb.ConnCase, async: false

  alias Caredeck.{Feed, Org}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "Attachment Test", slug: "att-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility_a =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "Att A", slug: "att-a-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility_b =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "Att B", slug: "att-b-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    %{facility_a: facility_a, facility_b: facility_b}
  end

  test "anonymous request returns 401", %{conn: conn} do
    conn = get(conn, ~p"/attachments/photos/missing.jpg")
    assert conn.status == 401
    assert conn.resp_body == "Sign in required."
  end

  test "key belonging to a different facility returns 404", ctx do
    team_a = create_team(ctx.facility_a, "team-a")
    post_a = create_post(ctx.facility_a, team_a)
    attachment_a = create_attachment(ctx.facility_a, post_a, "photos/secret-a.jpg")

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.assign(:current_facility, ctx.facility_b)
      |> get(~p"/attachments/#{attachment_a.s3_key}")

    assert conn.status == 404
  end

  test "key belonging to current facility resolves the tenancy guard", ctx do
    team_a = create_team(ctx.facility_a, "team-a")
    post_a = create_post(ctx.facility_a, team_a)
    attachment_a = create_attachment(ctx.facility_a, post_a, "photos/visible-a.jpg")

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.assign(:current_facility, ctx.facility_a)
      |> get(~p"/attachments/#{attachment_a.s3_key}")

    assert conn.status in [200, 404]
  end

  defp create_team(facility, handle) do
    Caredeck.Accounts.TeamIdentity
    |> Ash.Changeset.for_create(
      :register_with_password,
      %{
        handle: handle,
        name: handle,
        role_kind: :care,
        facility_id: facility.id,
        password: "test-password-1234"
      },
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  defp create_post(facility, team) do
    Feed.Post
    |> Ash.Changeset.for_create(
      :create,
      %{facility_id: facility.id, team_identity_id: team.id, body: "test"},
      tenant: facility.id,
      authorize?: false
    )
    |> Ash.create!(tenant: facility.id, authorize?: false)
  end

  defp create_attachment(facility, post, key) do
    Application.put_env(:caredeck, :thumbnailer_mode, :off)

    Feed.Attachment
    |> Ash.Changeset.for_create(
      :create,
      %{
        facility_id: facility.id,
        post_id: post.id,
        kind: :photo,
        s3_key: key,
        mime_type: "image/jpeg",
        bytes: 100,
        position: 0
      },
      tenant: facility.id,
      authorize?: false
    )
    |> Ash.create!(tenant: facility.id, authorize?: false)
  end
end
