defmodule Boomb.Repo.Migrations.AddSessionExpiryMinutesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :session_expiry_minutes, :integer, default: nil
    end
  end
end