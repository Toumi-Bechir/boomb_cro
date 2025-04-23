# lib/boomb_web/controllers/user_controller.ex
defmodule BoombWeb.UserController do
  use BoombWeb, :controller

  alias Boomb.Accounts
  alias Boomb.Accounts.User

  def new(conn, _params) do
    changeset = User.registration_changeset(%User{}, %{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params, "_return_to" => return_to} = params) do
    return_to = if return_to in ["", nil], do: ~p"/login", else: return_to

    case Accounts.register_user(user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Registration successful! Please check your email to activate your account.")
        |> redirect(to: return_to)

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  #def create(conn, params) do
  #  create(conn, Map.put(params, "_return_to", ~p"/login"))
  #end
end