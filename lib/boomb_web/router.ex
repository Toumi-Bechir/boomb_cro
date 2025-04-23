defmodule BoombWeb.Router do
  use BoombWeb, :router

  defmodule AuthPlug do
    import Plug.Conn
    use Phoenix.VerifiedRoutes, endpoint: BoombWeb.Endpoint, router: BoombWeb.Router
    def init(opts), do: opts
    def call(conn, _opts) do
      if user_id = get_session(conn, :user_id) do
        user = Boomb.Accounts.get_user!(user_id)
        assign(conn, :current_user, user)
      else
      # Only update return_to if the current path is not /login or /register
       return_to = get_session(conn, :return_to) || ~p"/"
       full_uri = conn.request_path <> if(conn.query_string != "", do: "?" <> conn.query_string, else: "")
        new_return_to = 
          if conn.request_path not in ["/login", "/register"] do
           full_uri # conn.request_path
          else
            return_to
          end
        conn
        |> put_session(:return_to, new_return_to)
        |> assign(:current_user, nil)
      end
    end
  end

  defmodule EnsureAuthPlug do
    import Plug.Conn
    # Import Phoenix.VerifiedRoutes to use ~p sigil
    use Phoenix.VerifiedRoutes, endpoint: BoombWeb.Endpoint, router: BoombWeb.Router

    def init(opts), do: opts
    def call(conn, _opts) do
      if get_session(conn, :user_id) do
        conn
      else
      full_uri = conn.request_path <> if(conn.query_string != "", do: "?" <> conn.query_string, else: "")
        conn
        |> put_session(:return_to, full_uri)
        |> redirect(to: ~p"/login?return_to=#{conn.request_path}")
        |> halt()
      end
    end
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :fetch_live_flash
    plug :put_root_layout, html: {BoombWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug AuthPlug # Always run to set current_user and store return_to
  end

  pipeline :ensure_auth do
    plug EnsureAuthPlug # Only redirect if not logged in
  end

  # Public routes (no authentication required)
  scope "/", BoombWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/register", SessionController, :new_registration
    post "/register", SessionController, :create_registration
    get "/login", SessionController, :new
    post "/login", SessionController, :create
    delete "/logout", SessionController, :delete

    # Public LiveView routes
    live "/", OverviewLive
    live "/inplay", OverviewLive
    live "/event/:event_id", EventLive
    live "/test", TestLive
  end

  # Protected routes requiring authentication
  scope "/", BoombWeb do
    pipe_through [:browser, :ensure_auth]

    # Example protected routes (add more as needed)
    live "/dashboard", DashboardLive
  end

  # Public pregame routes
  scope "/pregame", BoombWeb.Pregame do
    pipe_through :browser

    live "/", SportsLive, :index
    live "/matches", MatchesLive, :index
    live "/match/:match_id", MatchDetailsLive, :index
  end

  if Application.compile_env(:boomb, :dev_routes) do
    import Phoenix.LiveDashboard.Router
    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: BoombWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end