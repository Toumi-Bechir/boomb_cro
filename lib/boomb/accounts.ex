defmodule Boomb.Accounts do
  import Ecto.Query, warn: false
  alias Boomb.Repo
  alias Boomb.Accounts.User
  alias Boomb.Session
  alias Boomb.Emails

  # Rate limiting configuration
  @max_failed_attempts Application.compile_env(:boomb, [:rate_limiting, :max_failed_attempts], 5)
  @lock_duration_minutes Application.compile_env(:boomb, [:rate_limiting, :lock_duration_minutes], 30)

  # Session management configuration
  @session_expiry_minutes Application.compile_env(:boomb, [:session_management, :session_expiry_minutes], 60)
  @max_concurrent_sessions Application.compile_env(:boomb, [:session_management, :max_concurrent_sessions], 3)

  def change_user_registration(user, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end

  def register_user(attrs) do
    result =
      %User{}
      |> User.registration_changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, user} ->
        Emails.confirmation_email(user)
        {:ok, user}
      error ->
        error
    end
  end

  def authenticate_user(email, password) do
    user = Repo.get_by(User, email: String.downcase(email))

    IO.inspect({@max_failed_attempts, @lock_duration_minutes}, label: "Rate Limiting Config")

    case user do
      nil ->
        Argon2.no_user_verify()
        {:error, :invalid_credentials}

      user ->
        user = Repo.reload(user) || user
        IO.inspect({user.failed_login_attempts, user.locked_until}, label: "User State Before Check")

        case check_account_lock(user) do
          {:error, :account_locked} = error ->
            error

          :ok ->
            if user.active do
              if Argon2.verify_pass(password, user.password_hash) do
                token = generate_session_token()
                # Use user-specific expiry if set, otherwise fall back to default
                expiry_minutes = user.session_expiry_minutes || @session_expiry_minutes
                expires_at = DateTime.utc_now() |> DateTime.add(expiry_minutes * 60, :second)

                user = manage_concurrent_sessions(user, token)

                session_attrs = %{
                  token: token,
                  user_id: user.id,
                  expires_at: expires_at,
                  device_info: nil,
                  ip_address: nil,
                  last_active_at: DateTime.utc_now()
                }

                case %Session{}
                     |> Session.changeset(session_attrs)
                     |> Repo.insert() do
                  {:ok, _session} ->
                    case user
                         |> User.login_changeset(%{failed_login_attempts: 0, locked_until: nil})
                         |> Repo.update() do
                      {:ok, updated_user} ->
                        {:ok, updated_user, token}
                      {:error, changeset} ->
                        IO.inspect(changeset, label: "Failed to Reset Attempts")
                        {:error, :update_failed}
                    end
                  {:error, changeset} ->
                    IO.inspect(changeset, label: "Failed to Create Session")
                    {:error, :session_creation_failed}
                end
              else
                updated_attempts = user.failed_login_attempts + 1
                IO.inspect(updated_attempts, label: "Updated Failed Attempts")

                locked_until =
                  if updated_attempts >= @max_failed_attempts do
                    DateTime.utc_now() |> DateTime.add(@lock_duration_minutes * 60, :second)
                  else
                    user.locked_until
                  end

                IO.inspect(locked_until, label: "Locked Until")

                changeset = User.login_changeset(user, %{
                  failed_login_attempts: updated_attempts,
                  locked_until: locked_until
                })
                IO.inspect(changeset, label: "Changeset Before Update")

                case Repo.update(changeset) do
                  {:ok, updated_user} ->
                    IO.inspect(updated_user.failed_login_attempts, label: "Updated User Failed Attempts")
                    if updated_user.failed_login_attempts >= @max_failed_attempts do
                      {:error, :account_locked}
                    else
                      {:error, :invalid_credentials}
                    end
                  {:error, changeset} ->
                    IO.inspect(changeset, label: "Failed to Update Attempts")
                    {:error, :update_failed}
                end
              end
            else
              {:error, :account_not_confirmed}
            end
        end
    end
  end

  def confirm_user(token) do
    case Repo.get_by(User, confirmation_token: token) do
      nil ->
        {:error, :invalid_token}

      user ->
        user
        |> User.confirm_changeset()
        |> Repo.update()
    end
  end

  def get_user(id) do
    Repo.get(User, id)
  end

  def get_user!(id) do
    Repo.get!(User, id)
  end

  # Validate a session token and return the associated user
  def validate_session(token) do
    case Repo.get_by(Session, token: token) do
      nil ->
        {:error, :invalid_session}

      session ->
        if DateTime.compare(session.expires_at, DateTime.utc_now()) == :gt do
          # Update last active time
          session
          |> Session.changeset(%{last_active_at: DateTime.utc_now()})
          |> Repo.update()

          user = Repo.get!(User, session.user_id)
          if token in (user.active_sessions || []) do
            {:ok, user}
          else
            {:error, :invalid_session}
          end
        else
          # Session expired, remove it
          remove_session(user_id: session.user_id, token: token)
          {:error, :session_expired}
        end
    end
  end

  # Update session with device info and IP address
  def update_session(token, device_info, ip_address) do
    case Repo.get_by(Session, token: token) do
      nil ->
        {:error, :invalid_session}

      session ->
        session
        |> Session.changeset(%{device_info: device_info, ip_address: ip_address})
        |> Repo.update()
    end
  end

  # Remove a specific session
  def remove_session(user_id: user_id, token: token) do
    Repo.transaction(fn ->
      # Remove from sessions table
      Repo.delete_all(from s in Session, where: s.token == ^token)

      # Update user's active_sessions
      user = Repo.get!(User, user_id)
      updated_sessions = (user.active_sessions || []) -- [token]
      user
      |> User.login_changeset(%{active_sessions: updated_sessions})
      |> Repo.update()
    end)
  end

  # Get all active sessions for a user
  def get_active_sessions(user_id) do
    Repo.all(
      from s in Session,
      where: s.user_id == ^user_id and s.expires_at > ^DateTime.utc_now()
    )
  end

  defp generate_session_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp manage_concurrent_sessions(user, new_token) do
    active_sessions = user.active_sessions || []
    current_sessions = active_sessions |> Enum.filter(fn token ->
      case validate_session(token) do
        {:ok, _} -> true
        _ -> false
      end
    end)

    if length(current_sessions) >= @max_concurrent_sessions do
      {oldest_token, remaining_sessions} = List.pop_at(current_sessions, 0)
      remove_session(user_id: user.id, token: oldest_token)
      user = Repo.reload(user)
      updated_sessions = remaining_sessions ++ [new_token]
      user
      |> User.login_changeset(%{active_sessions: updated_sessions})
      |> Repo.update!()
    else
      updated_sessions = current_sessions ++ [new_token]
      user
      |> User.login_changeset(%{active_sessions: updated_sessions})
      |> Repo.update!()
    end
  end

  defp check_account_lock(user) do
    case user.locked_until do
      nil ->
        :ok

      locked_until ->
        if DateTime.compare(locked_until, DateTime.utc_now()) == :gt do
          {:error, :account_locked}
        else
          # Unlock the account if the lock duration has expired
          case user
               |> User.login_changeset(%{failed_login_attempts: 0, locked_until: nil})
               |> Repo.update() do
            {:ok, _updated_user} ->
              :ok
            {:error, changeset} ->
              IO.inspect(changeset, label: "Failed to Unlock Account")
              {:error, :update_failed}
          end
        end
    end
  end
end