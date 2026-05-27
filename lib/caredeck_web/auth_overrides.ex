defmodule CaredeckWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  override AshAuthentication.Phoenix.Components.SignIn do
    set :show_banner, false
  end

  override AshAuthentication.Phoenix.Components.Password do
    set :show_banner, false
    set :sign_in_action_name, :sign_in_with_password
    set :register_action_name, :register_with_password
  end

  override AshAuthentication.Phoenix.Components.HorizontalRule do
    set :hide_text, true
  end
end
