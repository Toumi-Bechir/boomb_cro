defmodule Boomb.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions) do
      add :token, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :expires_at, :utc_datetime, null: false
      add :device_info, :string
      add :ip_address, :string
      add :last_active_at, :utc_datetime

      timestamps()
    end

    create index(:sessions, [:user_id])
    create unique_index(:sessions, [:token])
  end
end