defmodule Disputex.Payments.Stripe do
  @moduledoc """
  `Disputex.Payments` backed by stripity_stripe.
  """

  @behaviour Disputex.Payments

  @impl Disputex.Payments
  def fetch_dispute(id) when is_binary(id) do
    case Stripe.Dispute.retrieve(id) do
      {:ok, dispute} -> {:ok, normalize(dispute)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize(dispute) do
    %{
      id: dispute.id,
      charge_id: id_of(dispute.charge),
      payment_intent_id: id_of(dispute.payment_intent),
      amount: dispute.amount,
      currency: dispute.currency,
      reason: dispute.reason,
      status: dispute.status,
      evidence_due_by: due_by(dispute),
      livemode: dispute.livemode == true
    }
  end

  defp due_by(%{evidence_details: details}) when is_map(details) do
    case Map.get(details, :due_by) || Map.get(details, "due_by") do
      unix when is_integer(unix) ->
        unix |> DateTime.from_unix!() |> DateTime.truncate(:microsecond)

      _ ->
        nil
    end
  end

  defp due_by(_dispute), do: nil

  defp id_of(%{id: id}) when is_binary(id), do: id
  defp id_of(id) when is_binary(id), do: id
  defp id_of(_), do: nil
end
