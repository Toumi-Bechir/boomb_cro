defmodule Boomb.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :active, :boolean, default: false
    field :confirmation_token, :string
    field :failed_login_attempts, :integer, default: 0
    field :locked_until, :utc_datetime
    field :active_sessions, Boomb.Types.JsonArray, default: []
    field :session_expiry_minutes, :integer, default: nil # User-specific session expiry

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
    |> put_confirmation_token()
  end

  def login_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :failed_login_attempts, :locked_until, :active_sessions, :session_expiry_minutes])
    |> validate_required([:email])
    |> validate_number(:failed_login_attempts, greater_than_or_equal_to: 0)
  end

  def confirm_changeset(user) do
    user
    |> cast(%{}, [])
    |> put_change(:active, true)
    |> put_change(:confirmation_token, nil)
  end

  defp put_password_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        put_change(changeset, :password_hash, Argon2.hash_pwd_salt(password))
      _ ->
        changeset
    end
  end

  defp put_confirmation_token(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true} ->
        token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
        put_change(changeset, :confirmation_token, token)
      _ ->
        changeset
    end
  end
end