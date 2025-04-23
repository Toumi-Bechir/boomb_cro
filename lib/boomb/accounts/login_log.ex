# lib/boomb/accounts/login_log.ex
defmodule Boomb.Accounts.LoginLog do
  use Ecto.Schema

  schema "login_logs" do
    field :user_id, :integer
    field :success, :boolean
    field :ip_address, :string
    field :location, :string
    field :device, :string
    field :timezone, :string
    timestamps()
  end
end