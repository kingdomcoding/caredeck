defmodule Caredeck.Feed.MultitenancyTest do
  use Caredeck.DataCase, async: false

  alias Caredeck.{Accounts, Feed, Org}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "Feed Tenancy #{suffix}", slug: "fmt-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility_a =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "Feed A", slug: "fmt-a-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility_b =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "Feed B", slug: "fmt-b-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    team_a =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-fmt-#{suffix}",
          name: "Team A",
          role_kind: :care,
          facility_id: facility_a.id,
          password: "phase3-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    post_a =
      Feed.Post
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility_a.id, team_identity_id: team_a.id, body: "Hello A"},
        tenant: facility_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility_a.id, authorize?: false)

    %{facility_a: facility_a, facility_b: facility_b, post_a: post_a}
  end

  test "reading Feed.Post in tenant B does not return tenant A posts", ctx do
    rows = Ash.read!(Feed.Post, tenant: ctx.facility_b.id, authorize?: false)
    refute Enum.any?(rows, &(&1.id == ctx.post_a.id))
  end

  test "reading Feed.Post with correct tenant returns its rows", ctx do
    rows = Ash.read!(Feed.Post, tenant: ctx.facility_a.id, authorize?: false)
    assert Enum.any?(rows, &(&1.id == ctx.post_a.id))
  end

  test "reading Feed.Post without a tenant raises", _ctx do
    assert_raise Ash.Error.Invalid, fn ->
      Ash.read!(Feed.Post, authorize?: false)
    end
  end
end
