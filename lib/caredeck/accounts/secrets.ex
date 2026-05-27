defmodule Caredeck.Accounts.Secrets do
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], resource, _opts, _context)
      when resource in [Caredeck.Accounts.User, Caredeck.Accounts.TeamIdentity] do
    case Application.fetch_env(:caredeck, :token_signing_secret) do
      {:ok, secret} when is_binary(secret) -> {:ok, secret}
      _ -> :error
    end
  end

  def secret_for(_, _, _, _), do: :error
end
