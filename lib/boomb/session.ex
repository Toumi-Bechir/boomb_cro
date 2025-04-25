defmodule Boomb.Session do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sessions" do
    field :token, :string
    belongs_to :user, Boomb.Accounts.User
    field :expires_at, :utc_datetime
    field :device_info, :string
    field :ip_address, :string
    field :last_active_at, :utc_datetime

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:token, :user_id, :expires_at, :device_info, :ip_address, :last_active_at])
    |> validate_required([:token, :user_id, :expires_at])
    |> unique_constraint(:token)
  end
end