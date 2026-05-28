defmodule CaredeckWeb.Router do
  use CaredeckWeb, :router
  use AshAuthentication.Phoenix.Router
  import AshAdmin.Router

  @csp_header %{
    "content-security-policy" =>
      "default-src 'self'; img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self' ws: wss:; font-src 'self' data:; object-src 'none'; base-uri 'self'; frame-ancestors 'none'"
  }

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CaredeckWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers, @csp_header
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end

  scope "/", CaredeckWeb do
    get "/healthz", HealthController, :index
  end

  scope "/", CaredeckWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/design-system", DesignSystemLive

    auth_routes(AuthController, Caredeck.Accounts.User, path: "/auth")
    delete "/sign-out", AuthController, :sign_out

    live_session :no_user, on_mount: {CaredeckWeb.LiveUserAuth, :live_no_user} do
      live "/sign-in", Auth.SignInLive
      live "/register", Auth.RegisterLive
      live "/password-reset-request", Auth.ResetRequestLive
    end

    reset_route(auth_routes_prefix: "/auth")
    confirm_route(Caredeck.Accounts.User, :confirm_new_user, auth_routes_prefix: "/auth")

    live_session :authenticated,
      on_mount: {CaredeckWeb.LiveUserAuth, :live_signed_in_optional} do
      live "/feed", FeedLive
    end
  end

  scope "/team", CaredeckWeb do
    pipe_through :browser

    auth_routes(TeamAuthController, Caredeck.Accounts.TeamIdentity, path: "/auth")

    live_session :no_team, on_mount: {CaredeckWeb.LiveUserAuth, :live_no_team} do
      live "/sign-in", Auth.TeamSignInLive
    end

    get "/sign-out", TeamAuthController, :sign_out
  end

  scope "/" do
    pipe_through :browser
    ash_admin("/admin")
  end

  if Application.compile_env(:caredeck, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CaredeckWeb.Telemetry
    end
  end
end
