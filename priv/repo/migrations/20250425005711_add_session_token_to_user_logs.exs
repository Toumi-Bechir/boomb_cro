defmodule Boomb.Repo.Migrations.AddSessionTokenToUserLogs do
  use Ecto.Migration

  def change do
    alter table(:user_logs) do
      add :session_token, :string
    end
  end
end