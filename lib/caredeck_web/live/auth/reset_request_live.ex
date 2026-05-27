defmodule CaredeckWeb.Auth.ResetRequestLive do
  use CaredeckWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Reset your password")}
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

          <h1 class="text-display-sm text-center text-ink-900 mb-2">Reset your password</h1>
          <p class="text-center text-ink-500 text-sm mb-8">
            We'll send a reset link to your email.
          </p>

          <form
            action={~p"/auth/user/password/reset_request"}
            method="post"
            class="space-y-4 bg-card rounded-card shadow-card p-6"
          >
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

            <div>
              <label for="reset_email" class="block text-sm font-medium text-ink-700 mb-1">
                Email
              </label>
              <input
                id="reset_email"
                name="user[email]"
                type="email"
                autocomplete="email"
                required
                class="w-full px-4 py-3 rounded-button border border-divider bg-card text-ink-900 placeholder-ink-300 focus:outline-none focus:ring-2 focus:ring-teal-300"
              />
            </div>

            <button
              type="submit"
              class="w-full rounded-button bg-brand text-white py-3 font-medium hover:bg-teal-600 focus:outline-none focus:ring-2 focus:ring-teal-300 transition"
            >
              Send reset link
            </button>
          </form>

          <div class="mt-6 text-center">
            <.link
              navigate={~p"/sign-in"}
              class="text-sm text-brand hover:text-teal-700"
            >
              Back to sign in
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
