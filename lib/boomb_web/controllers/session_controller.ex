defmodule BoombWeb.SessionController do
  use BoombWeb, :controller

  alias Boomb.Accounts
  alias Boomb.Accounts.User
  alias Boomb.UserLogger

  def new_registration(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    render(conn, :new_registration, changeset: changeset)
  end

  def create_registration(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        UserLogger.log_attempt(conn, "registration", "success", user)
        conn
        |> put_flash(:info, "Registration successful! Please check your email to confirm your account.")
        |> redirect(to: ~p"/login")

      {:error, %Ecto.Changeset{} = changeset} ->
        error_message =
          changeset.errors
          |> Enum.map(fn {field, {msg, _opts}} -> "#{field}: #{msg}" end)
          |> Enum.join(", ")

        UserLogger.log_attempt(conn, "registration", "failure", nil, error_message)
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

    redirect_path =
      if return_to in ["/login", "/register"] do
        ~p"/inplay"
      else
        return_to
      end

    IO.inspect(redirect_path, label: "Redirect path")

    case Accounts.authenticate_user(email, password) do
      {:ok, user, session_token} ->
        device_info = get_device_info(conn)
        ip_address = get_ip_address(conn)
        Accounts.update_session(session_token, device_info, ip_address)

        UserLogger.log_attempt(conn, "login", "success", user, nil, session_token)
        conn
        |> clear_flash()
        |> put_session(:session_token, session_token)
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> delete_session(:return_to)
        |> put_flash(:info, "Logged in successfully!")
        |> redirect(to: redirect_path)

      {:error, :account_locked} ->
        UserLogger.log_attempt(conn, "login", "failure", nil, "Account is locked due to too many failed attempts")
        conn
        |> clear_flash()
        |> put_flash(:error, "Your account is locked due to too many failed login attempts. Please try again later.")
        |> render(:new, return_to: return_to)

      {:error, :account_not_confirmed} ->
        UserLogger.log_attempt(conn, "login", "failure", nil, "Account not confirmed")
        conn
        |> clear_flash()
        |> put_flash(:error, "Please confirm your account via the email link before logging in.")
        |> render(:new, return_to: return_to)

      {:error, :update_failed} ->
        UserLogger.log_attempt(conn, "login", "failure", nil, "Failed to update account state")
        conn
        |> clear_flash()
        |> put_flash(:error, "An error occurred while processing your login. Please try again.")
        |> render(:new, return_to: return_to)

      {:error, :session_creation_failed} ->
        UserLogger.log_attempt(conn, "login", "failure", nil, "Failed to create session")
        conn
        |> clear_flash()
        |> put_flash(:error, "An error occurred while creating your session. Please try again.")
        |> render(:new, return_to: return_to)

      {:error, _reason} ->
        UserLogger.log_attempt(conn, "login", "failure", nil, "Invalid email or password")
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
    token = get_session(conn, :session_token)
    if token do
      user_id = get_session(conn, :user_id)
      Accounts.remove_session(user_id: user_id, token: token)
    end

    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: ~p"/")
  end

  def list_sessions(conn, _params) do
    token = get_session(conn, :session_token)
    case Accounts.validate_session(token) do
      {:ok, user} ->
        sessions = Accounts.get_active_sessions(user.id)
        render(conn, :list_sessions, sessions: sessions, user: user)

      {:error, _reason} ->
        conn
        |> configure_session(drop: true)
        |> put_flash(:error, "Your session is invalid or has expired. Please log in again.")
        |> redirect(to: ~p"/login")
    end
  end

  def terminate_session(conn, %{"token" => token}) do
    current_token = get_session(conn, :session_token)
    user_id = get_session(conn, :user_id)

    if token == current_token do
      conn
      |> put_flash(:error, "You cannot terminate your current session from this page. Please log out instead.")
      |> redirect(to: ~p"/sessions")
    else
      case Accounts.remove_session(user_id: user_id, token: token) do
        {:ok, _} ->
          conn
          |> put_flash(:info, "Session terminated successfully.")
          |> redirect(to: ~p"/sessions")

        {:error, _reason} ->
          conn
          |> put_flash(:error, "Failed to terminate the session.")
          |> redirect(to: ~p"/sessions")
      end
    end
  end

  defp get_device_info(conn) do
    case get_req_header(conn, "user-agent") do
      [user_agent | _] -> user_agent
      _ -> "Unknown Device"
    end
  end

  defp get_ip_address(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded_ip | _] ->
        forwarded_ip |> String.split(",") |> List.first() |> String.trim()

      _ ->
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end
end