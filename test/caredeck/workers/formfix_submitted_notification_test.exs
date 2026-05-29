defmodule Caredeck.Workers.FormfixSubmittedNotificationTest do
  use Caredeck.DataCase, async: false
  use Oban.Testing, repo: Caredeck.Repo

  alias Caredeck.{Accounts, Formfix, Org, People}
  alias Caredeck.Notifications.Notification
  alias Caredeck.Workers.NotificationFanout

  require Ash.Query

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "AS #{suffix}", slug: "as-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "AS Home", slug: "as-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    requester_user = create_user("as-r-#{suffix}@example.test")
    other_relative_user = create_user("as-o-#{suffix}@example.test")
    care_user = create_user("as-c-#{suffix}@example.test")

    Org.FacilityMembership
    |> Ash.Changeset.for_create(
      :create,
      %{facility_id: facility.id, user_id: care_user.id, role: :caregiver, source: :manual},
      authorize?: false
    )
    |> Ash.create!(authorize?: false)

    resident =
      People.Resident
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, first_name: "Anne", last_name: "Smith"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    requester_relative = create_relative(facility, requester_user, "Requester")
    other_relative = create_relative(facility, other_relative_user, "Other")
    link_relative(facility, requester_relative, resident, :daughter)
    link_relative(facility, other_relative, resident, :son)

    application = Formfix.Applications.start_for_resident!(facility, resident, requester_user)

    %{
      facility: facility,
      requester_user: requester_user,
      other_relative_user: other_relative_user,
      care_user: care_user,
      application: application
    }
  end

  test "submitted fan-out notifies other relatives + care team but not the requester", ctx do
    perform_job(NotificationFanout, %{
      "event" => "application_submitted",
      "application_id" => ctx.application.id,
      "facility_id" => ctx.facility.id
    })

    rows =
      Notification
      |> Ash.Query.filter(verb == :submitted)
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    user_ids = rows |> Enum.map(& &1.user_id) |> Enum.sort()

    assert ctx.other_relative_user.id in user_ids
    assert ctx.care_user.id in user_ids
    refute ctx.requester_user.id in user_ids

    Enum.each(rows, fn n ->
      assert n.target_kind == :application
      assert n.target_id == ctx.application.id
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
          password: "phase10-test-pass",
          password_confirmation: "phase10-test-pass"
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
