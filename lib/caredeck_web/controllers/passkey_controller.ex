defmodule CaredeckWeb.PasskeyController do
  use CaredeckWeb, :controller

  require Ash.Query

  alias Caredeck.Accounts.UserPasskey

  def register_options(conn, _params) do
    case conn.assigns[:current_user] do
      nil ->
        conn |> put_status(:unauthorized) |> json(%{error: "sign_in_required"})

      user ->
        challenge = Wax.new_registration_challenge(attestation: "none")

        existing_credentials =
          UserPasskey
          |> Ash.Query.filter(user_id == ^user.id)
          |> Ash.read!(authorize?: false)
          |> Enum.map(
            &%{type: "public-key", id: Base.url_encode64(&1.credential_id, padding: false)}
          )

        conn
        |> put_session(:passkey_reg_challenge, :erlang.term_to_binary(challenge))
        |> json(%{
          challenge: Base.url_encode64(challenge.bytes, padding: false),
          rp: %{id: challenge.rp_id, name: "Caredeck"},
          user: %{
            id: Base.url_encode64(user_handle(user), padding: false),
            name: to_string(user.email),
            displayName: user.name || to_string(user.email)
          },
          pubKeyCredParams: [
            %{type: "public-key", alg: -7},
            %{type: "public-key", alg: -257}
          ],
          authenticatorSelection: %{userVerification: "preferred"},
          attestation: "none",
          timeout: 60_000,
          excludeCredentials: existing_credentials
        })
    end
  end

  def register_finish(conn, %{"credential" => credential} = params) do
    user = conn.assigns[:current_user]

    cond do
      is_nil(user) ->
        conn |> put_status(:unauthorized) |> json(%{error: "sign_in_required"})

      is_nil(get_session(conn, :passkey_reg_challenge)) ->
        conn |> put_status(:bad_request) |> json(%{error: "no_challenge"})

      true ->
        challenge =
          conn
          |> get_session(:passkey_reg_challenge)
          |> :erlang.binary_to_term()

        raw_id = Base.url_decode64!(credential["rawId"], padding: false)

        attestation_object =
          Base.url_decode64!(credential["response"]["attestationObject"], padding: false)

        client_data_json =
          Base.url_decode64!(credential["response"]["clientDataJSON"], padding: false)

        nickname = String.slice(params["nickname"] || "Device", 0, 64)

        case Wax.register(attestation_object, client_data_json, challenge) do
          {:ok, {auth_data, _attestation_result}} ->
            cred_data = auth_data.attested_credential_data

            UserPasskey
            |> Ash.Changeset.for_create(
              :create,
              %{
                user_id: user.id,
                credential_id: raw_id,
                public_key: :erlang.term_to_binary(cred_data.credential_public_key),
                sign_count: auth_data.sign_count || 0,
                aaguid: Base.encode16(cred_data.aaguid || <<>>, case: :lower),
                nickname: nickname
              },
              authorize?: false
            )
            |> Ash.create!(authorize?: false)

            conn
            |> delete_session(:passkey_reg_challenge)
            |> json(%{ok: true})

          {:error, reason} ->
            conn |> put_status(:bad_request) |> json(%{error: format_error(reason)})
        end
    end
  end

  def sign_in_options(conn, _params) do
    challenge = Wax.new_authentication_challenge(user_verification: "preferred")

    conn
    |> put_session(:passkey_auth_challenge, :erlang.term_to_binary(challenge))
    |> json(%{
      challenge: Base.url_encode64(challenge.bytes, padding: false),
      rpId: challenge.rp_id,
      timeout: 60_000,
      userVerification: "preferred"
    })
  end

  def sign_in_finish(conn, %{"credential" => credential}) do
    if is_nil(get_session(conn, :passkey_auth_challenge)) do
      conn |> put_status(:bad_request) |> json(%{error: "no_challenge"})
    else
      challenge =
        conn
        |> get_session(:passkey_auth_challenge)
        |> :erlang.binary_to_term()

      raw_id = Base.url_decode64!(credential["rawId"], padding: false)

      auth_data_bin =
        Base.url_decode64!(credential["response"]["authenticatorData"], padding: false)

      sig = Base.url_decode64!(credential["response"]["signature"], padding: false)

      client_data_json =
        Base.url_decode64!(credential["response"]["clientDataJSON"], padding: false)

      passkey =
        UserPasskey
        |> Ash.Query.filter(credential_id == ^raw_id)
        |> Ash.Query.load(:user)
        |> Ash.read_one!(authorize?: false)

      result =
        passkey &&
          Wax.authenticate(
            raw_id,
            auth_data_bin,
            sig,
            client_data_json,
            challenge,
            [{raw_id, :erlang.binary_to_term(passkey.public_key)}]
          )

      case result do
        {:ok, auth_data} ->
          passkey
          |> Ash.Changeset.for_update(:record_use, %{sign_count: auth_data.sign_count || 0},
            authorize?: false
          )
          |> Ash.update!(authorize?: false)

          conn
          |> delete_session(:passkey_auth_challenge)
          |> AshAuthentication.Plug.Helpers.store_in_session(passkey.user)
          |> json(%{ok: true, redirect: "/feed"})

        _ ->
          conn |> put_status(:unauthorized) |> json(%{error: "invalid_assertion"})
      end
    end
  end

  defp user_handle(user) do
    case Ecto.UUID.dump(user.id) do
      {:ok, raw} -> raw
      _ -> user.id
    end
  end

  defp format_error(%{__struct__: mod}), do: Atom.to_string(mod)
  defp format_error(other), do: inspect(other)
end
