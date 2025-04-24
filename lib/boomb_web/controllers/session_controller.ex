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
        |> put_flash(:info, "Registration successful! Please check your email to confirm your account.")
        |> redirect(to: ~p"/login")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new_registration, changeset: changeset)
    end
  end

  def new(conn, params) do
    return_to = params["return_to"] || get_session(conn, :return_to) || ~p"/"
    conn = put_session(conn, :return_to, return_to)
    render(conn, :new, return_to: return_to)
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password} = user_params}) do
    return_to = user_params["return_to"] || get_session(conn, :return_to) || ~p"/"
    IO.inspect(return_to, label: "Initial return_to")

    # Determine the redirect path
    redirect_path =
      if return_to in ["/login", "/register"] do
        ~p"/inplay"
      else
        return_to
      end

    IO.inspect(redirect_path, label: "Redirect path")

    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> clear_flash() # Clear previous flash messages
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> delete_session(:return_to)
        |> put_flash(:info, "Logged in successfully!")
        |> redirect(to: redirect_path)

      {:error, :account_not_confirmed} ->
        conn
        |> clear_flash()
        |> put_flash(:error, "Please confirm your account via the email link before logging in.")
        |> render(:new, return_to: return_to)

      {:error, _reason} ->
        conn
        |> clear_flash()
        |> put_flash(:error, "Invalid email or password.")
        |> render(:new, return_to: return_to)
    end
  end

  def confirm(conn, %{"token" => token}) do
    case Accounts.confirm_user(token) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Account confirmed! You can now log in.")
        |> redirect(to: ~p"/login")

      {:error, :invalid_token} ->
        conn
        |> put_flash(:error, "Invalid or expired confirmation token.")
        |> redirect(to: ~p"/login")
    end
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: ~p"/")
  end
end