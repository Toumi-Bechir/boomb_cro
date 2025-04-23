# priv/repo/migrations/20250421_add_security_fields_to_users.exs
defmodule Boomb.Repo.Migrations.AddSecurityFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :status, :string, default: "inactive"
      add :failed_login_attempts, :integer, default: 0
      add :locked_until, :utc_datetime
      add :last_login_at, :utc_datetime
      add :last_login_ip, :string
      add :last_login_location, :string
      add :last_login_device, :string
      add :local_timezone, :string
      add :active_sessions, :json, default: "[]"
    end
  end
end