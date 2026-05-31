defmodule Caredeck.Feed.AuthzTest do
  use Caredeck.DataCase, async: false

  alias Caredeck.{Accounts, Feed, Org, People}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district = create_district(suffix)
    facility_a = create_facility(district, "FA #{suffix}", "fa-#{suffix}")
    facility_b = create_facility(district, "FB #{suffix}", "fb-#{suffix}")

    team_a = create_team(facility_a, "team-a-#{suffix}")
    team_b = create_team(facility_b, "team-b-#{suffix}")

    user_a = create_user("ua-#{suffix}@example.test")
    user_b = create_user("ub-#{suffix}@example.test")
    create_membership(user_a, facility_a)
    create_membership(user_b, facility_a)

    resident_a = create_resident(facility_a, "Anna", "Smith")
    relative_a = create_relative(facility_a, user_a, "User A")
    link_relative(facility_a, relative_a, resident_a, :daughter)

    post_internal_a =
      create_post(facility_a, team_a, "internal A", true, [resident_a])

    post_public_a = create_post(facility_a, team_a, "public A", false, [])

    %{
      facility_a: facility_a,
      facility_b: facility_b,
      team_a: team_a,
      team_b: team_b,
      user_a: user_a,
      user_b: user_b,
      resident_a: resident_a,
      relative_a: relative_a,
      post_internal_a: post_internal_a,
      post_public_a: post_public_a
    }
  end

  describe "Post read" do
    test "relative in audience can read internal post", ctx do
      assert {:ok, post} =
               Ash.get(Feed.Post, ctx.post_internal_a.id,
                 tenant: ctx.facility_a.id,
                 actor: ctx.user_a
               )

      assert post.id == ctx.post_internal_a.id
    end

    test "relative not in audience cannot read internal post", ctx do
      assert {:error, _} =
               Ash.get(Feed.Post, ctx.post_internal_a.id,
                 tenant: ctx.facility_a.id,
                 actor: ctx.user_b
               )
    end

    test "relative not in audience can read public post", ctx do
      assert {:ok, post} =
               Ash.get(Feed.Post, ctx.post_public_a.id,
                 tenant: ctx.facility_a.id,
                 actor: ctx.user_b
               )

      assert post.id == ctx.post_public_a.id
    end

    test "team in same facility can read any post", ctx do
      assert {:ok, _} =
               Ash.get(Feed.Post, ctx.post_internal_a.id,
                 tenant: ctx.facility_a.id,
                 actor: ctx.team_a
               )
    end

    test "admin team can read internal post by another team in same facility", ctx do
      admin = create_team(ctx.facility_a, "admin-#{:erlang.unique_integer([:positive])}", :admin)

      assert {:ok, post} =
               Ash.get(Feed.Post, ctx.post_internal_a.id,
                 tenant: ctx.facility_a.id,
                 actor: admin
               )

      assert post.id == ctx.post_internal_a.id
    end

    test "admin team can read public post by another team in same facility", ctx do
      admin = create_team(ctx.facility_a, "admin-#{:erlang.unique_integer([:positive])}", :admin)

      assert {:ok, post} =
               Ash.get(Feed.Post, ctx.post_public_a.id,
                 tenant: ctx.facility_a.id,
                 actor: admin
               )

      assert post.id == ctx.post_public_a.id
    end
  end

  describe "Post create" do
    test "team can create post in own facility", ctx do
      assert {:ok, _post} =
               Feed.Post
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   facility_id: ctx.facility_a.id,
                   team_identity_id: ctx.team_a.id,
                   body: "new post"
                 },
                 tenant: ctx.facility_a.id,
                 actor: ctx.team_a
               )
               |> Ash.create()
    end

    test "team cannot create post with another team's id", ctx do
      assert {:error, _} =
               Feed.Post
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   facility_id: ctx.facility_a.id,
                   team_identity_id: ctx.team_b.id,
                   body: "spoof"
                 },
                 tenant: ctx.facility_a.id,
                 actor: ctx.team_a
               )
               |> Ash.create()
    end

    test "relative cannot create post", ctx do
      assert {:error, _} =
               Feed.Post
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   facility_id: ctx.facility_a.id,
                   team_identity_id: ctx.team_a.id,
                   body: "should fail"
                 },
                 tenant: ctx.facility_a.id,
                 actor: ctx.user_a
               )
               |> Ash.create()
    end
  end

  describe "Post update / destroy" do
    test "authoring team can update its own post", ctx do
      assert {:ok, _} =
               ctx.post_public_a
               |> Ash.Changeset.for_update(:update, %{body: "edited"},
                 tenant: ctx.facility_a.id,
                 actor: ctx.team_a
               )
               |> Ash.update()
    end

    test "another team cannot update someone else's post", ctx do
      other_team =
        create_team(ctx.facility_a, "other-team-#{:erlang.unique_integer([:positive])}")

      assert {:error, _} =
               ctx.post_public_a
               |> Ash.Changeset.for_update(:update, %{body: "edited"},
                 tenant: ctx.facility_a.id,
                 actor: other_team
               )
               |> Ash.update()
    end
  end

  describe "Comment create + update window" do
    test "relative in audience can comment", ctx do
      assert {:ok, _} =
               Feed.Comment
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   facility_id: ctx.facility_a.id,
                   post_id: ctx.post_internal_a.id,
                   author_user_id: ctx.user_a.id,
                   body: "thanks"
                 },
                 tenant: ctx.facility_a.id,
                 actor: ctx.user_a
               )
               |> Ash.create()
    end

    test "relative cannot create comment with someone else's author_user_id", ctx do
      assert {:error, _} =
               Feed.Comment
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   facility_id: ctx.facility_a.id,
                   post_id: ctx.post_internal_a.id,
                   author_user_id: ctx.user_b.id,
                   body: "spoof"
                 },
                 tenant: ctx.facility_a.id,
                 actor: ctx.user_a
               )
               |> Ash.create()
    end

    test "relative can edit own comment within 5 minutes", ctx do
      comment = create_comment(ctx.facility_a, ctx.post_internal_a, ctx.user_a, "ok")

      assert {:ok, _} =
               comment
               |> Ash.Changeset.for_update(:update, %{body: "fixed"},
                 tenant: ctx.facility_a.id,
                 actor: ctx.user_a
               )
               |> Ash.update()
    end

    test "relative cannot edit comment after 5 minutes", ctx do
      comment = create_comment(ctx.facility_a, ctx.post_internal_a, ctx.user_a, "ok")
      old_comment = %{comment | inserted_at: DateTime.add(DateTime.utc_now(), -600, :second)}

      assert {:error, _} =
               old_comment
               |> Ash.Changeset.for_update(:update, %{body: "too late"},
                 tenant: ctx.facility_a.id,
                 actor: ctx.user_a
               )
               |> Ash.update()
    end

    test "relative cannot edit another relative's comment", ctx do
      comment = create_comment(ctx.facility_a, ctx.post_internal_a, ctx.user_a, "ok")

      assert {:error, _} =
               comment
               |> Ash.Changeset.for_update(:update, %{body: "stealing"},
                 tenant: ctx.facility_a.id,
                 actor: ctx.user_b
               )
               |> Ash.update()
    end
  end

  describe "Reaction" do
    test "relative can create own reaction", ctx do
      assert {:ok, _} =
               Feed.Reaction
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   facility_id: ctx.facility_a.id,
                   post_id: ctx.post_internal_a.id,
                   user_id: ctx.user_a.id,
                   kind: :like
                 },
                 tenant: ctx.facility_a.id,
                 actor: ctx.user_a
               )
               |> Ash.create()
    end

    test "relative cannot create reaction for another user", ctx do
      assert {:error, _} =
               Feed.Reaction
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   facility_id: ctx.facility_a.id,
                   post_id: ctx.post_internal_a.id,
                   user_id: ctx.user_b.id,
                   kind: :like
                 },
                 tenant: ctx.facility_a.id,
                 actor: ctx.user_a
               )
               |> Ash.create()
    end

    test "team cannot create a reaction", ctx do
      assert {:error, _} =
               Feed.Reaction
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   facility_id: ctx.facility_a.id,
                   post_id: ctx.post_internal_a.id,
                   user_id: ctx.user_a.id,
                   kind: :like
                 },
                 tenant: ctx.facility_a.id,
                 actor: ctx.team_a
               )
               |> Ash.create()
    end

    test "relative can destroy own reaction", ctx do
      {:ok, reaction} =
        Feed.Reaction
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: ctx.facility_a.id,
            post_id: ctx.post_internal_a.id,
            user_id: ctx.user_a.id
          },
          tenant: ctx.facility_a.id,
          actor: ctx.user_a
        )
        |> Ash.create()

      assert :ok =
               Ash.destroy(reaction, tenant: ctx.facility_a.id, actor: ctx.user_a)
    end
  end

  describe "Cross-facility" do
    test "team in facility A cannot edit post in facility B", ctx do
      post_b = create_post(ctx.facility_b, ctx.team_b, "post B", false, [])

      assert_raise Ash.Error.Invalid, fn ->
        post_b
        |> Ash.Changeset.for_update(:update, %{body: "cross-facility edit"},
          tenant: ctx.facility_a.id,
          actor: ctx.team_a
        )
        |> Ash.update!()
      end
    end
  end

  defp create_district(suffix) do
    Org.District
    |> Ash.Changeset.for_create(
      :create,
      %{name: "Authz #{suffix}", slug: "authz-#{suffix}"},
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  defp create_facility(district, name, slug) do
    Org.Facility
    |> Ash.Changeset.for_create(
      :create,
      %{district_id: district.id, name: name, slug: slug},
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  defp create_team(facility, handle, role_kind \\ :care) do
    Accounts.TeamIdentity
    |> Ash.Changeset.for_create(
      :register_with_password,
      %{
        handle: handle,
        name: handle,
        role_kind: role_kind,
        facility_id: facility.id,
        password: "phase4-test-pass"
      },
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  defp create_user(email) do
    user =
      Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          email: email,
          name: "Test",
          family_name: "User",
          password: "phase4-test-pass",
          password_confirmation: "phase4-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user
    |> Ash.Changeset.for_update(:update_profile, %{}, authorize?: false)
    |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
    |> Ash.update!(authorize?: false)
  end

  defp create_membership(user, facility) do
    Org.FacilityMembership
    |> Ash.Changeset.for_create(
      :create,
      %{
        facility_id: facility.id,
        user_id: user.id,
        role: :relative,
        source: :manual
      },
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  defp create_resident(facility, first, last) do
    People.Resident
    |> Ash.Changeset.for_create(
      :create,
      %{facility_id: facility.id, first_name: first, last_name: last},
      tenant: facility.id,
      authorize?: false
    )
    |> Ash.create!(tenant: facility.id, authorize?: false)
  end

  defp create_relative(facility, user, display_name) do
    People.Relative
    |> Ash.Changeset.for_create(
      :create,
      %{
        facility_id: facility.id,
        user_id: user.id,
        display_name: display_name
      },
      tenant: facility.id,
      authorize?: false
    )
    |> Ash.create!(tenant: facility.id, authorize?: false)
  end

  defp link_relative(facility, relative, resident, relationship) do
    People.RelativeOfResident
    |> Ash.Changeset.for_create(
      :create,
      %{
        facility_id: facility.id,
        relative_id: relative.id,
        resident_id: resident.id,
        relationship: relationship
      },
      tenant: facility.id,
      authorize?: false
    )
    |> Ash.create!(tenant: facility.id, authorize?: false)
  end

  defp create_post(facility, team, body, is_internal, audience_residents) do
    post =
      Feed.Post
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          team_identity_id: team.id,
          body: body,
          is_internal: is_internal
        },
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    Enum.each(audience_residents, fn r ->
      Feed.PostAudience
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, post_id: post.id, resident_id: r.id},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)
    end)

    post
  end

  defp create_comment(facility, post, user, body) do
    Feed.Comment
    |> Ash.Changeset.for_create(
      :create,
      %{
        facility_id: facility.id,
        post_id: post.id,
        author_user_id: user.id,
        body: body
      },
      tenant: facility.id,
      authorize?: false
    )
    |> Ash.create!(tenant: facility.id, authorize?: false)
  end
end
