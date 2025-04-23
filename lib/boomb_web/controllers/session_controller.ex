defmodule BoombWeb.SessionController do
  use BoombWeb, :controller

  alias Boomb.Accounts
  alias Boomb.Accounts.User

  def new_registration(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    render(conn, :new_registration, changeset: changeset)
  end

  def create_registration(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Registration successful! Please log in.")
        |> redirect(to: ~p"/login")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new_registration, changeset: changeset)
    end
  end

  def new(conn, _params) do
    # Pass the return_to from session to the template if needed
    return_to = get_session(conn, :return_to) || ~p"/"
    render(conn, :new, return_to: return_to)
  end

 def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        return_to = get_session(conn, :return_to) || ~p"/"
        conn
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> delete_session(:return_to) # Clean up after use
        |> put_flash(:info, "Logged in successfully!")
        |> redirect(to: return_to)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> render(:new)
    end
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: ~p"/")
  end
end