defmodule Disputex.Domain.Seeds do
  @moduledoc """
  Deterministic fake hotel domain. `plan/0` reseeds `:rand` so two calls match.
  """

  alias Disputex.Domain.{AccessLog, Booking, Customer, EmailMessage, Policy, Stay}
  alias Disputex.Repo

  @customer_count 80
  @booking_count 200
  @first ~w(Ava Noah Mia Liam Zoe Ethan Luna Leo Nina Omar Maya Kai)
  @last ~w(Silva Costa Mendes Almeida Ferreira Souza Rocha Lima)
  @hotels [
    "Harbor House",
    "Cinder Court",
    "North Station Inn",
    "Lumen Hotel",
    "Rio Verde",
    "Glass Pier",
    "Old Mill Rooms",
    "Sable & Co"
  ]
  @countries ~w(US BR GB DE FR CA AU JP)
  @statuses [:confirmed, :cancelled, :completed, :no_show]
  @refunds [:none, :pending, :partial, :full]
  @events [:login, :booking_created, :voucher_opened]

  @doc "Build the seed plan. Does not touch the database."
  @spec plan() :: map()
  def plan do
    :rand.seed(:exsss, {2026, 10, 24})

    policies = policies()
    customers = Enum.map(1..@customer_count, &customer/1)
    bookings = Enum.map(1..@booking_count, &booking/1)

    stays =
      bookings
      |> Enum.with_index()
      |> Enum.filter(fn {row, _index} -> row.include_stay end)
      |> Enum.map(fn {row, index} -> stay(row, index) end)

    emails =
      Enum.flat_map(Enum.with_index(bookings), fn {row, index} ->
        emails(row, index)
      end)

    logs = Enum.flat_map(Enum.with_index(customers), fn {row, index} -> logs(row, index) end)

    %{
      policies: policies,
      customers: customers,
      bookings: bookings,
      stays: stays,
      emails: emails,
      access_logs: logs
    }
  end

  @doc "Insert `plan/0` when the domain is empty."
  @spec insert!() :: {:ok, map() | :already_seeded}
  def insert! do
    Repo.transaction(
      fn ->
        if Disputex.Domain.empty?() do
          persist(plan())
        else
          :already_seeded
        end
      end,
      timeout: 60_000
    )
  end

  defp persist(plan) do
    policies = Enum.map(plan.policies, &insert!(Policy, &1))
    customers = Enum.map(plan.customers, &insert!(Customer, &1.attrs))
    cancellation = Enum.find(policies, &(&1.kind == :cancellation))

    bookings =
      Enum.map(plan.bookings, fn row ->
        attrs =
          Map.merge(row.attrs, %{
            customer_id: Enum.at(customers, row.customer_index).id,
            cancellation_policy_id: cancellation.id
          })

        insert!(Booking, attrs)
      end)

    Enum.each(plan.stays, fn row ->
      insert!(Stay, Map.put(row.attrs, :booking_id, Enum.at(bookings, row.booking_index).id))
    end)

    Enum.each(plan.emails, fn row ->
      insert!(
        EmailMessage,
        Map.put(row.attrs, :booking_id, Enum.at(bookings, row.booking_index).id)
      )
    end)

    Enum.each(plan.access_logs, fn row ->
      insert!(
        AccessLog,
        Map.put(row.attrs, :customer_id, Enum.at(customers, row.customer_index).id)
      )
    end)

    %{bookings: length(bookings), customers: length(customers)}
  end

  defp insert!(schema, attrs) do
    schema
    |> struct()
    |> schema.changeset(attrs)
    |> Repo.insert!()
  end

  defp policies do
    [
      %{
        kind: :cancellation,
        version: "2026-01",
        body:
          "Free cancellation until 48 hours before check-in. Inside that window the first night is kept."
      },
      %{
        kind: :refund,
        version: "2026-01",
        body:
          "Refunds return to the original card within 10 business days. No-shows are not refunded."
      },
      %{
        kind: :terms,
        version: "2026-01",
        body:
          "A booking is a stay at the named hotel for the listed dates. The guest must present the name on the reservation."
      }
    ]
  end

  defp customer(i) do
    first = Enum.at(@first, rem(i - 1, length(@first)))
    last = Enum.at(@last, rem(i - 1, length(@last)))
    name = first <> " " <> last

    %{
      attrs: %{
        name: name,
        email: String.downcase(first) <> "." <> String.downcase(last) <> "#{i}@example.test",
        phone: "+1 415 555 " <> String.pad_leading(Integer.to_string(1000 + i), 4, "0"),
        country: Enum.at(@countries, rem(i, length(@countries))),
        account_created_at:
          DateTime.new!(Date.add(~D[2023-03-01], rem(i * 7, 600)), ~T[12:00:00.000000], "Etc/UTC"),
        prior_bookings_count: rem(i, 9)
      }
    }
  end

  defp booking(i) do
    status = Enum.at(@statuses, :rand.uniform(length(@statuses)) - 1)
    check_in = Date.add(~D[2026-01-10], rem(i * 3, 220))
    nights = 1 + rem(i, 6)
    customer_index = rem(i - 1, @customer_count)

    %{
      customer_index: customer_index,
      include_stay:
        status in [:completed, :no_show] or (status == :confirmed and :rand.uniform(3) == 1),
      email_count: rem(i, 4),
      guest_name: guest_name(customer_index),
      attrs: %{
        ref: "BK-#{1000 + i}",
        hotel: Enum.at(@hotels, :rand.uniform(length(@hotels)) - 1),
        check_in: check_in,
        check_out: Date.add(check_in, nights),
        amount: 8_000 + :rand.uniform(70_000),
        status: status,
        stripe_charge_id: "ch_seed_" <> String.pad_leading(Integer.to_string(i), 4, "0"),
        refund_status: refund_status(status),
        policy_accepted_at: DateTime.new!(Date.add(check_in, -3), ~T[15:04:00.000000], "Etc/UTC")
      }
    }
  end

  defp guest_name(customer_index) do
    i = customer_index + 1

    Enum.at(@first, rem(i - 1, length(@first))) <>
      " " <> Enum.at(@last, rem(i - 1, length(@last)))
  end

  defp refund_status(:cancelled), do: Enum.at(@refunds, :rand.uniform(length(@refunds)) - 1)
  defp refund_status(_), do: :none

  defp stay(booking, index) do
    check_in_at = DateTime.new!(booking.attrs.check_in, ~T[16:10:00.000000], "Etc/UTC")

    checked_in_at = if booking.attrs.status == :no_show, do: nil, else: check_in_at

    checked_out_at =
      if booking.attrs.status == :completed do
        DateTime.new!(booking.attrs.check_out, ~T[11:00:00.000000], "Etc/UTC")
      end

    %{
      booking_index: index,
      attrs: %{
        checked_in_at: checked_in_at,
        checked_out_at: checked_out_at,
        id_verified: booking.attrs.status != :no_show and :rand.uniform(5) != 1,
        room_charges: :rand.uniform(12_000)
      }
    }
  end

  defp emails(booking, index) do
    Enum.map(1..booking.email_count//1, fn n ->
      direction = if rem(n, 2) == 1, do: :inbound, else: :outbound

      %{
        booking_index: index,
        attrs: %{
          direction: direction,
          sent_at:
            DateTime.new!(Date.add(booking.attrs.check_in, -n), ~T[09:30:00.000000], "Etc/UTC"),
          subject: "Booking #{booking.attrs.ref}",
          body: email_body(direction, booking)
        }
      }
    end)
  end

  defp email_body(:inbound, booking) do
    "Hi, this is #{booking.guest_name}. Please confirm #{booking.attrs.ref} at #{booking.attrs.hotel}."
  end

  defp email_body(:outbound, booking) do
    "Your stay #{booking.attrs.ref} is #{booking.attrs.status}. Reply if the dates are wrong."
  end

  defp logs(_customer, index) do
    count = 2 + rem(index, 3)

    Enum.map(1..count, fn n ->
      %{
        customer_index: index,
        attrs: %{
          event: Enum.at(@events, rem(n, length(@events))),
          ip: "203.0.113.#{rem(index * 3 + n, 200) + 1}",
          user_agent: "DisputexSeed/1.0",
          device_fingerprint: "dev-#{index}-#{rem(n, 2)}",
          at:
            DateTime.new!(
              Date.add(~D[2026-01-01], rem(index + n, 200)),
              ~T[08:00:00.000000],
              "Etc/UTC"
            )
        }
      }
    end)
  end
end
