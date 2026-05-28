defmodule CaredeckWeb.Auth.RegisterLive do
  use CaredeckWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Create your account")}
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

          <h1 class="text-display-sm text-center text-ink-900 mb-2">Create your account</h1>
          <p class="text-center text-ink-500 text-sm mb-8">
            Stay close to your loved one's daily life.
          </p>

          <form
            action={~p"/auth/user/password/register"}
            method="post"
            class="space-y-4 bg-card rounded-card shadow-card p-6"
          >
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

            <div class="grid grid-cols-2 gap-3">
              <div>
                <label for="reg_name" class="block text-sm font-medium text-ink-700 mb-1">
                  First name
                </label>
                <input
                  id="reg_name"
                  name="user[name]"
                  type="text"
                  required
                  class="w-full px-4 py-3 rounded-button border border-divider bg-card text-ink-900 placeholder-ink-300 focus:outline-none focus:ring-2 focus:ring-teal-300"
                />
              </div>
              <div>
                <label for="reg_family_name" class="block text-sm font-medium text-ink-700 mb-1">
                  Last name
                </label>
                <input
                  id="reg_family_name"
                  name="user[family_name]"
                  type="text"
                  required
                  class="w-full px-4 py-3 rounded-button border border-divider bg-card text-ink-900 placeholder-ink-300 focus:outline-none focus:ring-2 focus:ring-teal-300"
                />
              </div>
            </div>

            <div>
              <label for="reg_email" class="block text-sm font-medium text-ink-700 mb-1">
                Email
              </label>
              <input
                id="reg_email"
                name="user[email]"
                type="email"
                autocomplete="email"
                required
                class="w-full px-4 py-3 rounded-button border border-divider bg-card text-ink-900 placeholder-ink-300 focus:outline-none focus:ring-2 focus:ring-teal-300"
              />
            </div>

            <div>
              <label for="reg_password" class="block text-sm font-medium text-ink-700 mb-1">
                Password
              </label>
              <input
                id="reg_password"
                name="user[password]"
                type="password"
                autocomplete="new-password"
                required
                minlength="8"
                class="w-full px-4 py-3 rounded-button border border-divider bg-card text-ink-900 placeholder-ink-300 focus:outline-none focus:ring-2 focus:ring-teal-300"
              />
            </div>

            <div>
              <label
                for="reg_password_confirmation"
                class="block text-sm font-medium text-ink-700 mb-1"
              >
                Confirm password
              </label>
              <input
                id="reg_password_confirmation"
                name="user[password_confirmation]"
                type="password"
                autocomplete="new-password"
                required
                class="w-full px-4 py-3 rounded-button border border-divider bg-card text-ink-900 placeholder-ink-300 focus:outline-none focus:ring-2 focus:ring-teal-300"
              />
            </div>

            <button
              type="submit"
              class="w-full rounded-button bg-brand text-white py-3 font-medium hover:bg-teal-600 focus:outline-none focus:ring-2 focus:ring-teal-300 transition"
            >
              Create account
            </button>
          </form>

          <div class="mt-6 text-center">
            <p class="text-sm text-ink-500">
              Already have an account?
              <.link
                navigate={~p"/sign-in"}
                class="text-brand hover:text-teal-700 font-medium"
              >
                Sign in
              </.link>
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
