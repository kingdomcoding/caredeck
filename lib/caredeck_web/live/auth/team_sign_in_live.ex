defmodule CaredeckWeb.Auth.TeamSignInLive do
  use CaredeckWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Team sign in")}
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

          <h1 class="text-display-sm text-center text-ink-900 mb-2">Team sign in</h1>
          <p class="text-center text-ink-500 text-sm mb-8">
            Sign in to your shared caregiver account.
          </p>

          <form
            action={~p"/team/auth/team_identity/password/sign_in"}
            method="post"
            class="space-y-4 bg-card rounded-card shadow-card p-6"
          >
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

            <div>
              <label for="team_handle" class="block text-sm font-medium text-ink-700 mb-1">
                Handle
              </label>
              <input
                id="team_handle"
                name="team_identity[handle]"
                type="text"
                autocomplete="username"
                required
                placeholder="team-care"
                class="w-full px-4 py-3 rounded-button border border-divider bg-card text-ink-900 placeholder-ink-300 focus:outline-none focus:ring-2 focus:ring-teal-300"
              />
            </div>

            <div>
              <label for="team_password" class="block text-sm font-medium text-ink-700 mb-1">
                Password
              </label>
              <input
                id="team_password"
                name="team_identity[password]"
                type="password"
                autocomplete="current-password"
                required
                class="w-full px-4 py-3 rounded-button border border-divider bg-card text-ink-900 placeholder-ink-300 focus:outline-none focus:ring-2 focus:ring-teal-300"
              />
            </div>

            <button
              type="submit"
              class="w-full rounded-button bg-brand text-white py-3 font-medium hover:bg-teal-600 focus:outline-none focus:ring-2 focus:ring-teal-300 transition"
            >
              Sign in
            </button>
          </form>

          <div class="mt-6 text-center">
            <.link
              navigate={~p"/sign-in"}
              class="text-sm text-ink-500 hover:text-ink-900"
            >
              ← Relative? Sign in here
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
