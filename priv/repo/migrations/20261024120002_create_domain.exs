defmodule Disputex.Repo.Migrations.CreateDomain do
  use Ecto.Migration

  def change do
    create table(:policies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :kind, :string, null: false
      add :version, :string, null: false
      add :body, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create table(:customers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :email, :string, null: false
      add :phone, :string, null: false
      add :country, :string, null: false
      add :account_created_at, :utc_datetime_usec, null: false
      add :prior_bookings_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create index(:customers, [:email])

    create table(:bookings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :ref, :string, null: false
      add :hotel, :string, null: false
      add :check_in, :date, null: false
      add :check_out, :date, null: false
      add :amount, :integer, null: false
      add :status, :string, null: false
      add :stripe_charge_id, :string, null: false
      add :refund_status, :string, null: false
      add :policy_accepted_at, :utc_datetime_usec, null: false

      add :customer_id, references(:customers, type: :binary_id, on_delete: :restrict),
        null: false

      add :cancellation_policy_id, references(:policies, type: :binary_id, on_delete: :restrict),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:bookings, [:ref])
    create unique_index(:bookings, [:stripe_charge_id])
    create index(:bookings, [:customer_id])

    create table(:stays, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :checked_in_at, :utc_datetime_usec
      add :checked_out_at, :utc_datetime_usec
      add :id_verified, :boolean, null: false, default: false
      add :room_charges, :integer, null: false, default: 0

      add :booking_id, references(:bookings, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:stays, [:booking_id])

    create table(:email_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :direction, :string, null: false
      add :sent_at, :utc_datetime_usec, null: false
      add :subject, :string, null: false
      add :body, :text, null: false

      add :booking_id, references(:bookings, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:email_messages, [:booking_id])

    create table(:access_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event, :string, null: false
      add :ip, :string, null: false
      add :user_agent, :string, null: false
      add :device_fingerprint, :string, null: false
      add :at, :utc_datetime_usec, null: false

      add :customer_id, references(:customers, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:access_logs, [:customer_id])
  end
end
