defmodule Caredeck.Feed.PostFanoutTest do
  use Caredeck.DataCase, async: false
  use Oban.Testing, repo: Caredeck.Repo

  alias Caredeck.{Accounts, Feed, Org}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "Fanout #{suffix}", slug: "fanout-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "Fanout Home", slug: "fanout-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-fanout-#{suffix}",
          name: "Team Fanout",
          role_kind: :care,
          facility_id: facility.id,
          password: "phase3-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    %{facility: facility, team: team}
  end

  test "creating a post enqueues a NotificationFanout job", ctx do
    post =
      Feed.Post
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: ctx.facility.id, team_identity_id: ctx.team.id, body: "ping"},
        tenant: ctx.facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: ctx.facility.id, authorize?: false)

    assert_enqueued(
      worker: Caredeck.Workers.NotificationFanout,
      args: %{post_id: post.id, facility_id: ctx.facility.id}
    )
  end
end
