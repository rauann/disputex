defmodule Disputex.Repo.Migrations.EnablePgvector do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS vector", "DROP EXTENSION IF EXISTS vector"
  end

  def down do
    execute "DROP EXTENSION IF EXISTS vector", "CREATE EXTENSION IF NOT EXISTS vector"
  end
end
