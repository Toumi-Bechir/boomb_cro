defmodule BoombWeb.Router do
  use BoombWeb, :router

  defmodule AuthPlug do
    import Plug.Conn
    use Phoenix.VerifiedRoutes, endpoint: BoombWeb.Endpoint, router: BoombWeb.Router

    def init(opts), do: opts
    def call(conn, _opts) do
      if user_id = get_session(conn, :user_id) do
        case Boomb.Accounts.get_user(user_id) do
          nil ->
            conn
            |> configure_session(drop: true)
            |> put_flash(:info, "Your session has expired. Please log in again.")
            |> redirect(to: ~p"/login")
            |> halt()

          user ->
            assign(conn, :current_user, user)
        end
      else
        full_uri = conn.request_path <> if(conn.query_string != "", do: "?" <> conn.query_string, else: "")
        return_to = get_session(conn, :return_to) || ~p"/inplay"
        new_return_to =
          if conn.request_path not in ["/login", "/register", "/confirm", "/dev/mailbox/assets/app.css"] do 
            full_uri
          else
            return_to
          end
IO.puts "----------return _to:---#{return_to}-----new_return_to--#{new_return_to}--------"
        conn
        |> put_session(:return_to, new_return_to)
        |> assign(:current_user, nil)
      end
    end
  end

  defmodule EnsureAuthPlug do
    import Plug.Conn
    use Phoenix.VerifiedRoutes, endpoint: BoombWeb.Endpoint, router: BoombWeb.Router

    def init(opts), do: opts
    def call(conn, _opts) do
      if get_session(conn, :user_id) do
        conn
      else
        full_uri = conn.request_path <> if(conn.query_string != "", do: "?" <> conn.query_string, else: "")
        conn
        |> put_session(:return_to, full_uri)
        |> redirect(to: ~p"/login?return_to=#{full_uri}")
        |> halt()
      end
    end
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash # Ensure this is present for controllers
    plug :fetch_live_flash # Ensure this is present for LiveView
    plug :put_root_layout, html: {BoombWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug AuthPlug
  end

  pipeline :ensure_auth do
    plug EnsureAuthPlug
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
    get "/confirm", SessionController, :confirm # New route for confirmation

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