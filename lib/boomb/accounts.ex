defmodule Boomb.Accounts do
  import Ecto.Query, warn: false
  alias Boomb.Repo
  alias Boomb.Accounts.User
  alias Boomb.Emails

  # Rate limiting configuration
  @max_failed_attempts Application.compile_env(:boomb, [:rate_limiting, :max_failed_attempts], 5)
  @lock_duration_minutes Application.compile_env(:boomb, [:rate_limiting, :lock_duration_minutes], 30)

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
        # Reload user to ensure we have the latest data
        user = Repo.reload(user) || user

        IO.inspect({user.failed_login_attempts, user.locked_until}, label: "User State Before Check")

        # Check if the account is locked
        case check_account_lock(user) do
          {:error, :account_locked} = error ->
            error

          :ok ->
            if user.active do
              if Argon2.verify_pass(password, user.password_hash) do
                # Reset failed login attempts on successful login
                case user
                     |> User.login_changeset(%{failed_login_attempts: 0, locked_until: nil})
                     |> Repo.update() do
                  {:ok, updated_user} ->
                    {:ok, updated_user}
                  {:error, changeset} ->
                    IO.inspect(changeset, label: "Failed to Reset Attempts")
                    {:error, :update_failed}
                end
              else
                # Increment failed login attempts on failure
                updated_attempts = user.failed_login_attempts + 1

                IO.inspect(updated_attempts, label: "Updated Failed Attempts")

                # Check if the maximum attempts have been exceeded
                # Temporarily removing locked_until update as per your request
                attrs = %{
                  failed_login_attempts: updated_attempts
                  # locked_until is not updated for now
                }

                IO.inspect(attrs, label: "Attributes to Update")

                # Debug the changeset before update
                changeset = User.login_changeset(user, attrs)
                IO.inspect(changeset, label: "Changeset Before Update")

                case Repo.update(changeset) do
                  {:ok, updated_user} ->
                    IO.inspect(updated_user.failed_login_attempts, label: "Updated User Failed Attempts")
                    # Check if the maximum attempts have been exceeded
                    if updated_user.failed_login_attempts >= @max_failed_attempts do
                      locked_until = DateTime.utc_now() |> DateTime.add(@lock_duration_minutes * 60, :second)
                      IO.inspect(locked_until, label: "Locked Until")

                      # Update the user with locked_until
                      case updated_user
                           |> User.login_changeset(%{locked_until: locked_until})
                           |> Repo.update() do
                        {:ok, _final_user} ->
                          {:error, :account_locked}
                        {:error, changeset} ->
                          IO.inspect(changeset, label: "Failed to Lock Account")
                          {:error, :update_failed}
                      end
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