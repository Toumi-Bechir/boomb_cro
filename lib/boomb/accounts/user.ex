# lib/boomb/accounts/user.ex
defmodule Boomb.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true # Virtual field for password input
    field :password_hash, :string
    field :active, :boolean, default: false
    #field :status, :string, default: "inactive" # For email verification
    #field :failed_login_attempts, :integer, default: 0
    #field :locked_until, :utc_datetime # For account locking
    #field :last_login_at, :utc_datetime
    #field :last_login_ip, :string
    #field :last_login_location, :string
    #field :last_login_device, :string
    #field :local_timezone, :string
    #field :active_sessions, {:array, :string}, default: [] # Store session tokens

    timestamps()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email)
    |> validate_length(:password, min: 8)
    |> put_password_hash()
  end

  def login_changeset(user, attrs) do
    user
    |> cast(attrs, [:failed_login_attempts, :locked_until, :last_login_at, :last_login_ip, :last_login_location, :last_login_device, :local_timezone, :active_sessions])
    |> validate_required([:email])
  end

  defp put_password_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        put_change(changeset, :password_hash,Argon2.hash_pwd_salt(password))
      _ ->
        changeset
    end
  end
end