defmodule CaredeckWeb.PasskeyControllerTest do
  use CaredeckWeb.ConnCase, async: false

  alias Caredeck.Accounts

  setup do
    suffix = :erlang.unique_integer([:positive])
    %{user: register_user("pkc-#{suffix}@example.test")}
  end

  test "POST /passkey/register/options without auth returns 401", %{conn: conn} do
    conn = json_post(conn, ~p"/passkey/register/options", %{})
    assert json_response(conn, 401)["error"] == "sign_in_required"
  end

  test "POST /passkey/register/options with auth returns a challenge + rp + user", ctx do
    conn = sign_in(ctx.conn, ctx.user)
    conn = json_post(conn, ~p"/passkey/register/options", %{})

    body = json_response(conn, 200)
    assert is_binary(body["challenge"])
    assert %{"id" => _, "name" => _} = body["rp"]
    assert body["user"]["name"] == to_string(ctx.user.email)
    assert is_list(body["pubKeyCredParams"])
  end

  test "POST /passkey/sign-in/options (no auth required) returns a challenge + rpId", %{
    conn: conn
  } do
    conn = json_post(conn, ~p"/passkey/sign-in/options", %{})
    body = json_response(conn, 200)
    assert is_binary(body["challenge"])
    assert is_binary(body["rpId"])
    assert body["userVerification"] == "preferred"
  end

  test "POST /passkey/register/finish without an active challenge returns 400", ctx do
    conn = sign_in(ctx.conn, ctx.user)

    conn =
      json_post(conn, ~p"/passkey/register/finish", %{
        "credential" => %{
          "rawId" => "AAAA",
          "response" => %{
            "attestationObject" => "AAAA",
            "clientDataJSON" => "AAAA"
          }
        },
        "nickname" => "Test"
      })

    assert json_response(conn, 400)["error"] == "no_challenge"
  end

  test "POST /passkey/sign-in/finish without an active challenge returns 400", %{conn: conn} do
    conn =
      json_post(conn, ~p"/passkey/sign-in/finish", %{
        "credential" => %{
          "rawId" => "AAAA",
          "response" => %{
            "authenticatorData" => "AAAA",
            "clientDataJSON" => "AAAA",
            "signature" => "AAAA"
          }
        }
      })

    assert json_response(conn, 400)["error"] == "no_challenge"
  end

  defp json_post(conn, path, params) do
    conn
    |> Plug.Conn.put_req_header("accept", "application/json")
    |> post(path, params)
  end

  defp register_user(email) do
    user =
      Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          email: email,
          name: "Pass",
          family_name: "User",
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

  defp sign_in(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)
  end
end
