defmodule Boomb.Accounts do
  import Ecto.Query, warn: false
  alias Boomb.Repo
  alias Boomb.Accounts.User

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
        Boomb.Emails.confirmation_email(user)
        {:ok, user}
      error ->
        error
    end
  end

  def authenticate_user(email, password) do
    user = Repo.get_by(User, email: String.downcase(email))

    case user do
      nil ->
        Argon2.no_user_verify()
        {:error, :invalid_credentials}

      user ->
        # Reload the user to ensure we have the latest data
        user = Repo.reload(user) || user
        if user.active do
          if Argon2.verify_pass(password, user.password_hash) do
            {:ok, user}
          else
            {:error, :invalid_credentials}
          end
        else
          {:error, :account_not_confirmed}
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

  def get_user!(id) do
    Repo.get!(User, id)
  end

  def get_user(id) do
    Repo.get(User, id)
  end
end