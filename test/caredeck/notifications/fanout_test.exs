defmodule Caredeck.Notifications.FanoutTest do
  use Caredeck.DataCase, async: false
  use Oban.Testing, repo: Caredeck.Repo

  alias Caredeck.{Accounts, Feed, Org, People}
  alias Caredeck.Notifications.Notification
  alias Caredeck.Workers.NotificationFanout

  require Ash.Query

  setup do
    suffix = :erlang.unique_integer([:positive])

    district = create_district(suffix)
    facility = create_facility(district, "Fanout #{suffix}", "fanout-#{suffix}")

    team = create_team(facility, "team-fanout-#{suffix}")

    user_a = create_user("ua-fanout-#{suffix}@example.test")
    user_b = create_user("ub-fanout-#{suffix}@example.test")

    resident = create_resident(facility, "Anna", "Becker")

    relative_a = create_relative(facility, user_a, "User A")
    relative_b = create_relative(facility, user_b, "User B")
    link_relative(facility, relative_a, resident, :daughter)
    link_relative(facility, relative_b, resident, :son)

    post = create_post(facility, team, "hello family", true, [resident])

    %{
      facility: facility,
      team: team,
      user_a: user_a,
      user_b: user_b,
      resident: resident,
      post: post
    }
  end

  test "post_created produces a :posted notification for every audience member", ctx do
    perform_job!(%{
      "event" => "post_created",
      "post_id" => ctx.post.id,
      "facility_id" => ctx.facility.id
    })

    rows = list_notifications(ctx.facility.id)

    user_ids = rows |> Enum.map(& &1.user_id) |> Enum.sort()
    assert user_ids == Enum.sort([ctx.user_a.id, ctx.user_b.id])

    Enum.each(rows, fn n ->
      assert n.verb == :posted
      assert n.actor_kind == :team
      assert n.actor_id == ctx.team.id
      assert n.target_kind == :post
      assert n.target_id == ctx.post.id
    end)
  end

  test "comment_created excludes the comment author", ctx do
    comment =
      Feed.Comment
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: ctx.facility.id,
          post_id: ctx.post.id,
          author_user_id: ctx.user_a.id,
          body: "thanks!"
        },
        tenant: ctx.facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: ctx.facility.id, authorize?: false)

    drain_jobs()

    rows = list_notifications(ctx.facility.id) |> Enum.filter(&(&1.verb == :commented))

    assert Enum.map(rows, & &1.user_id) == [ctx.user_b.id]
    [n] = rows
    assert n.actor_kind == :user
    assert n.actor_id == ctx.user_a.id
    assert n.target_kind == :post
    assert n.target_id == comment.post_id
  end

  test "reaction_created excludes the reactor", ctx do
    reaction =
      Feed.Reaction
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: ctx.facility.id,
          post_id: ctx.post.id,
          user_id: ctx.user_a.id,
          kind: :like
        },
        tenant: ctx.facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: ctx.facility.id, authorize?: false)

    drain_jobs()

    rows = list_notifications(ctx.facility.id) |> Enum.filter(&(&1.verb == :liked))

    assert Enum.map(rows, & &1.user_id) == [ctx.user_b.id]
    [n] = rows
    assert n.actor_kind == :user
    assert n.actor_id == ctx.user_a.id
    assert n.target_id == reaction.post_id
  end

  test "invitation_accepted notifies the existing family minus the joiner", ctx do
    inviter = ctx.user_a
    joiner_email = "joiner-#{:erlang.unique_integer([:positive])}@example.test"
    joiner = create_user(joiner_email)

    invitation =
      People.RelativeInvitation
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: ctx.facility.id,
          inviter_user_id: inviter.id,
          resident_id: ctx.resident.id,
          email: joiner_email,
          suggested_relationship: :son
        },
        tenant: ctx.facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: ctx.facility.id, authorize?: false)

    joiner_relative = create_relative(ctx.facility, joiner, "Joiner")
    link_relative(ctx.facility, joiner_relative, ctx.resident, :son)

    invitation
    |> Ash.Changeset.for_update(:accept, %{}, tenant: ctx.facility.id, authorize?: false)
    |> Ash.update!(tenant: ctx.facility.id, authorize?: false)

    drain_jobs()

    rows = list_notifications(ctx.facility.id) |> Enum.filter(&(&1.verb == :joined))

    user_ids = rows |> Enum.map(& &1.user_id) |> Enum.sort()
    assert user_ids == Enum.sort([ctx.user_a.id, ctx.user_b.id])

    Enum.each(rows, fn n ->
      assert n.actor_kind == :user
      assert n.actor_id == joiner.id
      assert n.target_kind == :resident
      assert n.target_id == ctx.resident.id
    end)
  end

  test "running the same post_created job twice produces one notification per user", ctx do
    args = %{
      "event" => "post_created",
      "post_id" => ctx.post.id,
      "facility_id" => ctx.facility.id
    }

    perform_job!(args)
    perform_job!(args)

    rows = list_notifications(ctx.facility.id) |> Enum.filter(&(&1.verb == :posted))
    assert length(rows) == 2
    assert rows |> Enum.map(& &1.user_id) |> Enum.sort() ==
             Enum.sort([ctx.user_a.id, ctx.user_b.id])
  end

  test "reaction_created does not notify when the reactor is the only audience member", ctx do
    solo_user = create_user("solo-#{:erlang.unique_integer([:positive])}@example.test")
    solo_resident = create_resident(ctx.facility, "Solo", "Resident")
    solo_relative = create_relative(ctx.facility, solo_user, "Solo")
    link_relative(ctx.facility, solo_relative, solo_resident, :daughter)

    solo_post = create_post(ctx.facility, ctx.team, "solo body", true, [solo_resident])
    drain_jobs()

    Feed.Reaction
    |> Ash.Changeset.for_create(
      :create,
      %{
        facility_id: ctx.facility.id,
        post_id: solo_post.id,
        user_id: solo_user.id,
        kind: :like
      },
      tenant: ctx.facility.id,
      authorize?: false
    )
    |> Ash.create!(tenant: ctx.facility.id, authorize?: false)

    drain_jobs()

    rows =
      list_notifications(ctx.facility.id)
      |> Enum.filter(&(&1.verb == :liked and &1.target_id == solo_post.id))

    assert rows == []
  end

  defp perform_job!(args) do
    perform_job(NotificationFanout, args)
  end

  defp drain_jobs do
    Oban.drain_queue(queue: :fanout, with_safety: false)
  end

  defp list_notifications(facility_id) do
    Notification
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.read!(tenant: facility_id, authorize?: false)
  end

  defp create_district(suffix) do
    Org.District
    |> Ash.Changeset.for_create(
      :create,
      %{name: "Notif #{suffix}", slug: "notif-#{suffix}"},
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

  defp create_team(facility, handle) do
    Accounts.TeamIdentity
    |> Ash.Changeset.for_create(
      :register_with_password,
      %{
        handle: handle,
        name: handle,
        role_kind: :care,
        facility_id: facility.id,
        password: "phase6-test-pass"
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
          password: "phase6-test-pass",
          password_confirmation: "phase6-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user
    |> Ash.Changeset.for_update(:update_profile, %{}, authorize?: false)
    |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
    |> Ash.update!(authorize?: false)
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
end
