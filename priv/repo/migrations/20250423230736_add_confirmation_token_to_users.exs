defmodule Boomb.Repo.Migrations.AddConfirmationTokenToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :confirmation_token, :string
    end

    create index(:users, [:confirmation_token], unique: true)
  end
end
