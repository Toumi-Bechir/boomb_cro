defmodule Boomb.Accounts do
  import Ecto.Query, warn: false
  alias Boomb.Repo
  alias Boomb.Accounts.User

  def change_user_registration(user, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def authenticate_user(email, password) do
    user = Repo.get_by(User, email: String.downcase(email))

    case user do
      nil ->
        # Prevent timing attacks by running a dummy hash
        Argon2.no_user_verify()
        {:error, :invalid_credentials}

      user ->
        if Argon2.verify_pass(password, user.password_hash) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  def get_user!(id) do
    Repo.get!(User, id)
  end
end