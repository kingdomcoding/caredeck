defmodule Caredeck.Notifications.PruneOldNotificationsTest do
  use Caredeck.DataCase, async: false

  alias Caredeck.{Accounts, Org}
  alias Caredeck.Notifications.Notification
  alias Caredeck.Workers.PruneOldNotifications

  require Ash.Query

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "Prune #{suffix}", slug: "prune-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "Prune Home", slug: "prune-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user =
      Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          email: "prune-#{suffix}@example.test",
          name: "Prune",
          family_name: "User",
          password: "phase6-test-pass",
          password_confirmation: "phase6-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    fresh = build_notification(facility, user)
    stale = build_notification(facility, user, verb: :liked)

    backdate_inserted_at(stale, DateTime.add(DateTime.utc_now(), -100, :day))

    %{facility: facility, fresh: fresh, stale: stale}
  end

  test "removes notifications older than 90 days and keeps recent ones", ctx do
    PruneOldNotifications.perform(%Oban.Job{args: %{}})

    remaining_ids =
      Notification
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)
      |> Enum.map(& &1.id)

    assert ctx.fresh.id in remaining_ids
    refute ctx.stale.id in remaining_ids
  end

  defp build_notification(facility, user, overrides \\ []) do
    attrs =
      Enum.into(overrides, %{
        facility_id: facility.id,
        user_id: user.id,
        actor_kind: :user,
        actor_id: Ash.UUID.generate(),
        verb: :commented,
        target_kind: :post,
        target_id: Ash.UUID.generate()
      })

    Notification
    |> Ash.Changeset.for_create(:create, attrs, tenant: facility.id, authorize?: false)
    |> Ash.create!(tenant: facility.id, authorize?: false)
  end

  defp backdate_inserted_at(notification, %DateTime{} = ts) do
    import Ecto.Query

    from(n in "notifications", where: n.id == type(^notification.id, :binary_id))
    |> Caredeck.Repo.update_all(set: [inserted_at: ts])
  end
end
