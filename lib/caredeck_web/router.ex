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
    sign_out_route(AuthController)

    sign_in_route(
      register_path: "/register",
      reset_path: "/password-reset-request",
      auth_routes_prefix: "/auth",
      on_mount: [{CaredeckWeb.LiveUserAuth, :live_no_user}],
      overrides: [CaredeckWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )

    reset_route(auth_routes_prefix: "/auth")
    confirm_route(Caredeck.Accounts.User, :confirm_new_user, auth_routes_prefix: "/auth")
  end

  scope "/team", CaredeckWeb do
    pipe_through :browser

    auth_routes(TeamAuthController, Caredeck.Accounts.TeamIdentity, path: "/auth")

    sign_in_route(
      register_path: nil,
      reset_path: nil,
      auth_routes_prefix: "/team/auth",
      live_view: AshAuthentication.Phoenix.SignInLive,
      on_mount: [{CaredeckWeb.LiveUserAuth, :live_no_team}],
      as: :team_auth,
      overrides: [CaredeckWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )

    get "/sign-out", TeamAuthController, :sign_out
  end

  scope "/" do
    pipe_through :browser
    ash_admin("/admin")
  end

  # Other scopes may use custom stacks.
  # scope "/api", CaredeckWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:caredeck, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CaredeckWeb.Telemetry
    end
  end
end
