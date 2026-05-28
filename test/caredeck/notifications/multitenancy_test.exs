defmodule Caredeck.Notifications.MultitenancyTest do
  use Caredeck.DataCase, async: false

  alias Caredeck.{Accounts, Org}
  alias Caredeck.Notifications.Notification

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "Notif Tenancy #{suffix}", slug: "nt-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility_a =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "Notif A", slug: "nt-a-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility_b =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "Notif B", slug: "nt-b-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user_a = register_user("a-#{suffix}@example.test")
    user_b = register_user("b-#{suffix}@example.test")

    actor_id = Ash.UUID.generate()

    notif_a =
      Notification
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility_a.id,
          user_id: user_a.id,
          actor_kind: :user,
          actor_id: actor_id,
          verb: :commented,
          target_kind: :post,
          target_id: Ash.UUID.generate()
        },
        tenant: facility_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility_a.id, authorize?: false)

    %{
      facility_a: facility_a,
      facility_b: facility_b,
      user_a: user_a,
      user_b: user_b,
      notif_a: notif_a
    }
  end

  test "reading Notification without a tenant raises", _ctx do
    assert_raise Ash.Error.Invalid, fn ->
      Ash.read!(Notification, authorize?: false)
    end
  end

  test "another user cannot read someone else's notification", ctx do
    assert {:error, _} =
             Ash.get(Notification, ctx.notif_a.id,
               tenant: ctx.facility_a.id,
               actor: ctx.user_b
             )
  end

  test "the same user_id in another facility cannot see the notification", ctx do
    rows = Ash.read!(Notification, tenant: ctx.facility_b.id, actor: ctx.user_a)
    refute Enum.any?(rows, &(&1.id == ctx.notif_a.id))
  end

  defp register_user(email) do
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
end
