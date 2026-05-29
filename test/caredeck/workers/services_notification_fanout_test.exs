defmodule Caredeck.Workers.ServicesNotificationFanoutTest do
  use Caredeck.DataCase, async: false
  use Oban.Testing, repo: Caredeck.Repo

  alias Caredeck.{Accounts, Org, People, Services}
  alias Caredeck.Notifications.Notification
  alias Caredeck.Workers.NotificationFanout

  require Ash.Query

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "SVN #{suffix}", slug: "svn-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "SVN Home", slug: "svn-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    pharmacy_team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-pharmacy-svn-#{suffix}",
          name: "Pharmacy",
          role_kind: :service,
          facility_id: facility.id,
          password: "phase9-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user_a = create_user("svn-a-#{suffix}@example.test")
    user_b = create_user("svn-b-#{suffix}@example.test")

    resident =
      People.Resident
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, first_name: "Anna", last_name: "Becker"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    relative_a = create_relative(facility, user_a, "User A")
    relative_b = create_relative(facility, user_b, "User B")
    link_relative(facility, relative_a, resident, :daughter)
    link_relative(facility, relative_b, resident, :son)

    pharmacy =
      Services.ServiceProvider
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          kind: :pharmacy,
          name: "Apotheke",
          team_identity_id: pharmacy_team.id
        },
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    request =
      Services.ServiceRequest
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          provider_id: pharmacy.id,
          resident_id: resident.id,
          requester_user_id: user_a.id,
          subkind: "general_question",
          summary: "Q",
          payload: %{"subkind" => "general_question", "question" => "?"}
        },
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    %{
      facility: facility,
      pharmacy_team: pharmacy_team,
      user_a: user_a,
      user_b: user_b,
      resident: resident,
      pharmacy: pharmacy,
      request: request
    }
  end

  test "service_request_created notifies relatives except the requester", ctx do
    perform_job(NotificationFanout, %{
      "event" => "service_request_created",
      "request_id" => ctx.request.id,
      "facility_id" => ctx.facility.id
    })

    rows =
      Notification
      |> Ash.Query.filter(verb == :requested)
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert Enum.map(rows, & &1.user_id) == [ctx.user_b.id]
    [n] = rows
    assert n.actor_kind == :user
    assert n.actor_id == ctx.user_a.id
    assert n.target_kind == :service_request
    assert n.target_id == ctx.request.id
  end

  test "service_message_created notifies the requester and relatives except the author", ctx do
    message =
      Services.ServiceMessage
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: ctx.facility.id,
          service_request_id: ctx.request.id,
          author_team_id: ctx.pharmacy_team.id,
          body: "Got it."
        },
        tenant: ctx.facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: ctx.facility.id, authorize?: false)

    perform_job(NotificationFanout, %{
      "event" => "service_message_created",
      "message_id" => message.id,
      "facility_id" => ctx.facility.id
    })

    rows =
      Notification
      |> Ash.Query.filter(verb == :replied)
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    user_ids = rows |> Enum.map(& &1.user_id) |> Enum.sort()
    assert user_ids == Enum.sort([ctx.user_a.id, ctx.user_b.id])

    Enum.each(rows, fn n ->
      assert n.actor_kind == :team
      assert n.actor_id == ctx.pharmacy_team.id
      assert n.target_kind == :service_message
      assert n.target_id == message.id
    end)
  end

  defp create_user(email) do
    user =
      Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          email: email,
          name: "X",
          family_name: "Y",
          password: "phase9-test-pass",
          password_confirmation: "phase9-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user
    |> Ash.Changeset.for_update(:update_profile, %{}, authorize?: false)
    |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
    |> Ash.update!(authorize?: false)
  end

  defp create_relative(facility, user, display_name) do
    People.Relative
    |> Ash.Changeset.for_create(
      :create,
      %{facility_id: facility.id, user_id: user.id, display_name: display_name},
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
end
