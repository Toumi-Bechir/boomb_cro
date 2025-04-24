defmodule Boomb.Repo.Migrations.CreateUserLogs do
  use Ecto.Migration

  def change do
    create table(:user_logs) do
      add :user_id, references(:users, on_delete: :nilify_all), null: true
      add :action, :string, null: false # "registration" or "login"
      add :status, :string, null: false # "success" or "failure"
      add :attempts, :integer , default: 0
      add :ip_address, :string
      add :local_time, :string
      add :timezone, :string
      add :city, :string
      add :region, :string
      add :country, :string
      add :latitude, :float
      add :longitude, :float
      add :user_agent, :string
      add :device, :string
      add :device_type, :string
      add :os, :string
      add :browser, :string
      add :browser_version, :string
      add :error_message, :string

      timestamps()
    end

    create index(:user_logs, [:user_id])
    create index(:user_logs, [:action])
    create index(:user_logs, [:status])
  end
end