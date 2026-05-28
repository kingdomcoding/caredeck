defmodule CaredeckWeb.AttachmentControllerTest do
  use CaredeckWeb.ConnCase, async: false

  require Ash.Query

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Caredeck.Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "Attach Test", slug: "attach-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility_a =
      Caredeck.Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "A", slug: "a-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility_b =
      Caredeck.Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "B", slug: "b-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    team_a =
      Caredeck.Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-a-#{suffix}",
          name: "Team A",
          role_kind: :care,
          facility_id: facility_a.id,
          password: "phase3-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    post_a =
      Caredeck.Feed.Post
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility_a.id, team_identity_id: team_a.id, body: "hello A"},
        tenant: facility_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility_a.id, authorize?: false)

    key_a = "photos/test-#{suffix}.jpg"

    attachment_a =
      Caredeck.Feed.Attachment
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility_a.id,
          post_id: post_a.id,
          kind: :photo,
          s3_key: key_a,
          mime_type: "image/jpeg"
        },
        tenant: facility_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility_a.id, authorize?: false)

    user =
      Caredeck.Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          email: "attach-user-#{suffix}@example.test",
          name: "Test",
          family_name: "User",
          password: "phase3-test-pass",
          password_confirmation: "phase3-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user =
      user
      |> Ash.Changeset.for_update(:update_profile, %{}, authorize?: false)
      |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
      |> Ash.update!(authorize?: false)

    %{
      facility_a: facility_a,
      facility_b: facility_b,
      attachment_a: attachment_a,
      user: user
    }
  end

  test "anonymous request returns 401", %{conn: conn, attachment_a: a} do
    conn = get(conn, ~p"/attachments/#{a.s3_key}")
    assert conn.status == 401
  end

  test "signed-in user from a different facility gets 404", ctx do
    _ =
      Caredeck.Org.FacilityMembership
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: ctx.facility_b.id,
          user_id: ctx.user.id,
          role: :relative,
          source: :manual
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    conn =
      ctx.conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> AshAuthentication.Plug.Helpers.store_in_session(ctx.user)
      |> get(~p"/attachments/#{ctx.attachment_a.s3_key}")

    assert conn.status == 404
  end
end
