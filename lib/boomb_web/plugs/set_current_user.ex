# lib/boomb_web/plugs/set_current_user.ex
defmodule BoombWeb.Plugs.SetCurrentUser do
  import Plug.Conn

  alias Boomb.Repo
  alias Boomb.Accounts.User

  def init(_opts), do: nil

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)
    current_path = Phoenix.Controller.current_path(conn)

    conn =
      if user_id do
        user = Repo.get(User, user_id)
        assign(conn, :current_user, user)
      else
        assign(conn, :current_user, nil)
      end

    # Assign current_path directly to conn.assigns
    assign(conn, :current_path, current_path)
  end
end