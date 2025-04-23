# priv/repo/migrations/20250421_create_login_logs.exs
defmodule Boomb.Repo.Migrations.CreateLoginLogs do
  use Ecto.Migration

  def change do
    create table(:login_logs) do
      add :user_id, :integer
      add :success, :boolean
      add :ip_address, :string
      add :location, :string
      add :device, :string
      add :timezone, :string
      timestamps()
    end
  end
end