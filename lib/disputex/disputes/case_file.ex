defmodule Disputex.Disputes.CaseFile do
  @moduledoc """
  Compact, pre-redaction text for one dispute.

  Raw IPs, user agents, and email bodies stay out. The gather worker redacts
  the customer name, email, and phone before this text is stored.
  """

  import Ecto.Query

  alias Disputex.Domain.{AccessLog, EmailMessage}
  alias Disputex.Repo

  @spec build(Disputex.Disputes.Dispute.t()) :: %{text: String.t(), names: [String.t()]}
  def build(dispute) do
    booking = dispute.booking
    customer = booking && booking.customer
    stay = booking && booking.stay
    policy = booking && booking.cancellation_policy

    lines = [
      dispute_line(dispute),
      booking_line(booking),
      customer_line(customer),
      stay_line(stay),
      policy_line(policy, booking),
      "emails=#{email_count(booking)} access_logs=#{log_count(customer)}"
    ]

    %{
      text: Enum.join(lines, "\n"),
      names: names(customer)
    }
  end

  defp dispute_line(dispute) do
    "dispute #{dispute.stripe_dispute_id} reason=#{dispute.stripe_reason} status=#{dispute.stripe_status} amount=#{dispute.amount} #{dispute.currency} due=#{format_dt(dispute.evidence_due_by)}"
  end

  defp booking_line(nil), do: "booking unlinked"

  defp booking_line(booking) do
    "booking #{booking.ref} hotel=#{booking.hotel} check_in=#{booking.check_in} check_out=#{booking.check_out} status=#{booking.status} refund=#{booking.refund_status} amount=#{booking.amount}"
  end

  defp customer_line(nil), do: "customer unknown"

  defp customer_line(customer) do
    "customer name=#{customer.name} email=#{customer.email} phone=#{customer.phone} country=#{customer.country} prior_bookings=#{customer.prior_bookings_count}"
  end

  defp stay_line(nil), do: "stay none"

  defp stay_line(stay) do
    "stay checked_in=#{format_dt(stay.checked_in_at)} checked_out=#{format_dt(stay.checked_out_at)} id_verified=#{stay.id_verified} room_charges=#{stay.room_charges}"
  end

  defp policy_line(nil, _booking), do: "policy none"

  defp policy_line(policy, booking) do
    "policy #{policy.kind} version=#{policy.version} accepted_at=#{format_dt(booking.policy_accepted_at)}"
  end

  defp names(nil), do: []
  defp names(%{name: name}) when is_binary(name), do: [name]
  defp names(_), do: []

  defp email_count(nil), do: 0

  defp email_count(booking) do
    Repo.aggregate(
      from(message in EmailMessage, where: message.booking_id == ^booking.id),
      :count
    )
  end

  defp log_count(nil), do: 0

  defp log_count(customer) do
    Repo.aggregate(from(log in AccessLog, where: log.customer_id == ^customer.id), :count)
  end

  defp format_dt(nil), do: "none"
  defp format_dt(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp format_dt(%Date{} = date), do: Date.to_iso8601(date)
end
