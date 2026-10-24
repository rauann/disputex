defmodule Disputex.Repo.Migrations.CreatePiiVault do
  use Ecto.Migration

  def change do
    create table(:pii_vault, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :token, :string, null: false
      add :ciphertext, :binary, null: false

      add :dispute_id, references(:disputes, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:pii_vault, [:dispute_id, :token])
  end
end
