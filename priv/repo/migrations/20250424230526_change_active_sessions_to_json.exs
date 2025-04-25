defmodule Boomb.Repo.Migrations.ChangeActiveSessionsToJson do
  use Ecto.Migration

  def up do
    # Drop the existing column (if it exists) and recreate it as JSON
    alter table(:users) do
      remove :active_sessions
      add :active_sessions, :json, default: "[]"
    end
  end

  def down do
    # Revert to a string type (or whatever it was before) for rollback
    alter table(:users) do
      remove :active_sessions
      add :active_sessions, :string, default: "[]"
    end
  end
end
