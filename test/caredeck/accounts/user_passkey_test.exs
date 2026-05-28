defmodule Caredeck.Accounts.UserPasskeyTest do
  use Caredeck.DataCase, async: false

  alias Caredeck.Accounts
  alias Caredeck.Accounts.UserPasskey

  setup do
    suffix = :erlang.unique_integer([:positive])

    user_a = register_user("a-#{suffix}@example.test")
    user_b = register_user("b-#{suffix}@example.test")

    %{user_a: user_a, user_b: user_b}
  end

  test "creating a UserPasskey row requires user_id + credential_id + public_key", ctx do
    {:ok, _} =
      UserPasskey
      |> Ash.Changeset.for_create(:create, %{
        user_id: ctx.user_a.id,
        credential_id: <<1, 2, 3>>,
        public_key: <<4, 5, 6>>,
        sign_count: 0,
        nickname: "Test device"
      })
      |> Ash.create(authorize?: false)

    {:error, _} =
      UserPasskey
      |> Ash.Changeset.for_create(:create, %{user_id: ctx.user_a.id})
      |> Ash.create(authorize?: false)
  end

  test "unique_credential identity rejects duplicate credential_id", ctx do
    cred = <<11, 22, 33, 44>>

    {:ok, _} =
      UserPasskey
      |> Ash.Changeset.for_create(:create, %{
        user_id: ctx.user_a.id,
        credential_id: cred,
        public_key: <<>>
      })
      |> Ash.create(authorize?: false)

    {:error, _} =
      UserPasskey
      |> Ash.Changeset.for_create(:create, %{
        user_id: ctx.user_b.id,
        credential_id: cred,
        public_key: <<>>
      })
      |> Ash.create(authorize?: false)
  end

  test "destroy is authorized only for the owning user", ctx do
    passkey =
      UserPasskey
      |> Ash.Changeset.for_create(:create, %{
        user_id: ctx.user_a.id,
        credential_id: <<99, 99>>,
        public_key: <<>>
      })
      |> Ash.create!(authorize?: false)

    assert {:error, _} = Ash.destroy(passkey, actor: ctx.user_b)
    assert :ok == Ash.destroy(passkey, actor: ctx.user_a)
  end

  defp register_user(email) do
    user =
      Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          email: email,
          name: "Pass",
          family_name: "Key",
          password: "phase7-test-pass",
          password_confirmation: "phase7-test-pass"
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
