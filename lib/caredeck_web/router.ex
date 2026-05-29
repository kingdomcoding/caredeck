defmodule CaredeckWeb.Router do
  use CaredeckWeb, :router
  use AshAuthentication.Phoenix.Router

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

  pipeline :authenticated_browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers, @csp_header
    plug :load_from_session
    plug CaredeckWeb.Plugs.LoadCurrentFacility
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

    live_session :invitation,
      on_mount: {CaredeckWeb.LiveUserAuth, :live_signed_in_optional} do
      live "/invitations/:token", AcceptInvitationLive
    end

    reset_route(auth_routes_prefix: "/auth")
    confirm_route(Caredeck.Accounts.User, :confirm_new_user, auth_routes_prefix: "/auth")

    live_session :team_only,
      on_mount: {CaredeckWeb.LiveUserAuth, :live_team_required} do
      live "/feed/compose", PostComposeLive
      live "/feed/compose/:edit_post_id", PostComposeLive
    end

    live_session :team_kitchen,
      on_mount: {CaredeckWeb.LiveUserAuth, :live_team_required} do
      live "/kitchen/weekly-menu", Kitchen.WeeklyMenuLive
      live "/kitchen/weekly-menu/:date", Kitchen.DayEditorLive
      live "/kitchen/summary", Kitchen.SummaryLive
    end

    live_session :authenticated,
      on_mount: {CaredeckWeb.LiveUserAuth, :live_user_or_team_required} do
      live "/feed", FeedLive
      live "/feed/:post_id", PostLive
      live "/residents", ResidentsIndexLive
      live "/residents/:resident_id/invite", InviteRelativeLive
      live "/residents/:resident_id", ProfileLive
      live "/profile/edit", EditProfileLive
      live "/notifications", NotificationsLive
      live "/kitchen/order/:resident_id", Kitchen.ResidentOrderLive
      live "/residents/:resident_id/diet", Kitchen.DietProfileLive

      live "/services", Services.IndexLive
      live "/services/inbox", Services.InboxLive
      live "/services/requests/:request_id", Services.RequestLive
      live "/services/:provider_id/new", Services.NewRequestLive
      live "/services/:provider_id", Services.ProviderLive

      live "/aid", Aid.ListLive
      live "/aid/:application_id/overview", Aid.OverviewLive
      live "/aid/:application_id/section/:section_key", Aid.SectionLive
      live "/aid/:application_id/section/:section_key/documents", Aid.DocumentsLive
      live "/aid/:application_id/submit", Aid.SubmitLive
    end
  end

  scope "/", CaredeckWeb do
    pipe_through :authenticated_browser

    get "/attachments/*key", AttachmentController, :show
  end

  scope "/team", CaredeckWeb do
    pipe_through :browser

    auth_routes(TeamAuthController, Caredeck.Accounts.TeamIdentity, path: "/auth")

    live_session :no_team, on_mount: {CaredeckWeb.LiveUserAuth, :live_no_team} do
      live "/sign-in", Auth.TeamSignInLive
    end

    get "/sign-out", TeamAuthController, :sign_out
  end

  if Application.compile_env(:caredeck, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CaredeckWeb.Telemetry
    end
  end
end
