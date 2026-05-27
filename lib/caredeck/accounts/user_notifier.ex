defmodule Caredeck.Accounts.UserNotifier do
  use AshAuthentication.Sender
  import Swoosh.Email

  alias Caredeck.Mailer

  def send(user_or_email, token, opts) do
    strategy_name = strategy_from(opts)
    email_address = address_for(user_or_email)
    {subject, body} = compose(strategy_name, token)

    new()
    |> to(email_address)
    |> from(Application.fetch_env!(:caredeck, :from_email))
    |> subject(subject)
    |> html_body(body)
    |> Mailer.deliver()
  end

  defp strategy_from(opts) do
    case Keyword.get(opts, :strategy) do
      %{name: name} -> name
      name when is_atom(name) -> name
      _ -> :unknown
    end
  end

  defp address_for(%{email: email}), do: to_string(email)
  defp address_for(email) when is_binary(email), do: email
  defp address_for(email), do: to_string(email)

  defp compose(:confirm_new_user, token) do
    url = url_for("/auth/user/confirm_new_user?confirm=#{token}")

    {
      "Confirm your Caredeck account",
      """
      <p>Welcome to Caredeck.</p>
      <p>To finish setting up your account, click the link below:</p>
      <p><a href="#{url}">Confirm my email</a></p>
      <p>If you didn't request this, you can safely ignore this email.</p>
      """
    }
  end

  defp compose(:password, token) do
    url = url_for("/password-reset/#{token}")

    {
      "Reset your Caredeck password",
      """
      <p>We received a request to reset your password.</p>
      <p><a href="#{url}">Reset my password</a></p>
      <p>If you didn't request this, you can safely ignore this email.</p>
      """
    }
  end

  defp compose(_, _) do
    {"Caredeck notification", "<p>Caredeck sent you a notification.</p>"}
  end

  defp url_for(path) do
    CaredeckWeb.Endpoint.url() <> path
  end
end
