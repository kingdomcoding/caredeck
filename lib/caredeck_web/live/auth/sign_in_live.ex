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
        <div class="w-full max-w-md">
          <div class="bg-brand-soft border border-brand/40 rounded-card p-4 mb-6 text-sm text-ink-900">
            <p class="font-medium mb-1">Caredeck is a portfolio clone of <a href="https://myo.de" class="underline">myo</a>.</p>
            <p class="text-ink-700 text-xs">
              Built as my application for the <em>Senior Fullstack Engineer (Elixir/Phoenix)</em> role at Myosotis GmbH. The product is a working demo, not a live SaaS.
              <a href="https://github.com/kingdomcoding/caredeck" class="text-brand hover:underline whitespace-nowrap">View source →</a>
              ·
              <.link navigate={~p"/design-system"} class="text-brand hover:underline whitespace-nowrap">
                See the design tokens →
              </.link>
            </p>
          </div>

          <section class="bg-card rounded-card shadow-card p-5 mb-6">
            <p class="text-ink-500 text-xs uppercase tracking-wide mb-3">Jump in as a demo account</p>
            <div class="grid gap-2 sm:grid-cols-3">
              <.demo_button to={~p"/demo/admin"} label="Admin" sub="Phase 11 dashboard" />
              <.demo_button to={~p"/demo/care"} label="Care Team" sub="Feed · Residents · Inbox" />
              <.demo_button to={~p"/demo/relative"} label="Relative" sub="Family feed · Formfix" />
            </div>
          </section>

          <div class="flex justify-center mb-6">
            <img src={~p"/images/brand/caredeck-mark.svg"} alt="Caredeck" class="h-12 w-12" />
          </div>

          <h1 class="text-display-sm text-center text-ink-900 mb-2">Welcome to Caredeck</h1>
          <p class="text-center text-ink-500 text-sm mb-8">
            Or sign in with your own credentials.
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

          <footer class="mt-10 text-xs text-ink-500 text-center space-x-3">
            <a href="https://github.com/kingdomcoding/caredeck" class="hover:text-ink-900">Source</a>
            <span>·</span>
            <a
              href="https://github.com/kingdomcoding/caredeck/tree/master/docs/architecture/decisions"
              class="hover:text-ink-900"
            >ADRs</a>
            <span>·</span>
            <a
              href="https://github.com/kingdomcoding/caredeck/tree/master/docs/checkpoints"
              class="hover:text-ink-900"
            >Phase checkpoints</a>
          </footer>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :to, :string, required: true
  attr :label, :string, required: true
  attr :sub, :string, required: true

  defp demo_button(assigns) do
    ~H"""
    <form action={@to} method="post" class="contents">
      <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
      <button
        type="submit"
        class="w-full rounded-card border border-divider bg-card hover:border-brand text-left px-3 py-2 transition focus:outline-none focus-visible:ring-2 focus-visible:ring-teal-300 focus-visible:border-brand"
      >
        <p class="text-ink-900 font-medium text-sm">{@label}</p>
        <p class="text-ink-500 text-xs mt-0.5">{@sub}</p>
      </button>
    </form>
    """
  end
end
