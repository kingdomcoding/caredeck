defmodule CaredeckWeb.Auth.SignInLive do
  use CaredeckWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Sign in")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-[calc(100vh-65px)] flex items-center justify-center px-4 py-12">
        <div class="w-full max-w-sm">
          <div class="flex justify-center mb-6">
            <img src={~p"/images/brand/caredeck-mark.svg"} alt="Caredeck" class="h-12 w-12" />
          </div>

          <h1 class="text-display-sm text-center text-ink-900 mb-2">Welcome to Caredeck</h1>
          <p class="text-center text-ink-500 text-sm mb-8">
            Sign in to your existing profile.
          </p>

          <form
            action={~p"/auth/user/password/sign_in"}
            method="post"
            class="space-y-4 bg-card rounded-card shadow-card p-6"
          >
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

            <div>
              <label for="sign_in_email" class="block text-sm font-medium text-ink-700 mb-1">
                Email
              </label>
              <input
                id="sign_in_email"
                name="user[email]"
                type="email"
                autocomplete="email"
                required
                class="w-full px-4 py-3 rounded-button border border-divider bg-card text-ink-900 placeholder-ink-300 focus:outline-none focus:ring-2 focus:ring-teal-300 focus:border-teal-400"
              />
            </div>

            <div>
              <label for="sign_in_password" class="block text-sm font-medium text-ink-700 mb-1">
                Password
              </label>
              <input
                id="sign_in_password"
                name="user[password]"
                type="password"
                autocomplete="current-password"
                required
                class="w-full px-4 py-3 rounded-button border border-divider bg-card text-ink-900 placeholder-ink-300 focus:outline-none focus:ring-2 focus:ring-teal-300 focus:border-teal-400"
              />
            </div>

            <button
              type="submit"
              class="w-full rounded-button bg-brand text-white py-3 font-medium hover:bg-teal-600 focus:outline-none focus:ring-2 focus:ring-teal-300 transition"
            >
              Sign in
            </button>

            <div class="text-center pt-2">
              <.link
                navigate={~p"/password-reset-request"}
                class="text-sm text-brand hover:text-teal-700"
              >
                Forgot your password?
              </.link>
            </div>
          </form>

          <div class="mt-4 text-center">
            <button
              id="sign-in-passkey"
              type="button"
              phx-hook="PasskeySignIn"
              data-status-target="#passkey-status"
              class="w-full rounded-button bg-card border border-divider text-ink-900 py-3 hover:bg-page text-sm"
            >
              Use a passkey
            </button>
            <p id="passkey-status" class="text-ink-500 text-xs mt-2"></p>
          </div>

          <div class="mt-8 pt-6 border-t border-divider text-center">
            <p class="text-sm text-ink-500">
              Not yet registered?
              <.link
                navigate={~p"/register"}
                class="text-brand hover:text-teal-700 font-medium"
              >
                Create an account
              </.link>
            </p>
          </div>

          <div class="mt-6 text-center">
            <.link
              navigate={~p"/team/sign-in"}
              class="text-xs text-ink-300 hover:text-ink-500"
            >
              Caregiver? Sign in here →
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
