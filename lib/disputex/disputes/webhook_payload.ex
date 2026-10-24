defmodule Disputex.Disputes.WebhookPayload do
  @moduledoc """
  JSON-safe webhook payload stored on `webhook_events`.

  The worker re-fetches the dispute from Stripe, so the row keeps the event
  envelope and the dispute identifiers. Evidence and payment-method blobs,
  which can carry cardholder data, are dropped before insert.
  """

  @spec to_map(Stripe.Event.t()) :: map()
  def to_map(%Stripe.Event{} = event) do
    object = object_of(event.data)

    %{
      "id" => event.id,
      "type" => event.type,
      "livemode" => event.livemode == true,
      "created" => event.created,
      "data" => %{
        "object" => %{
          "id" => fetch(object, :id),
          "object" => fetch(object, :object) || "dispute",
          "charge" => id_of(fetch(object, :charge)),
          "payment_intent" => id_of(fetch(object, :payment_intent)),
          "amount" => fetch(object, :amount),
          "currency" => fetch(object, :currency),
          "reason" => fetch(object, :reason),
          "status" => fetch(object, :status),
          "livemode" => fetch(object, :livemode) == true
        }
      }
    }
  end

  @doc "Stripe dispute id carried on a stored payload."
  @spec dispute_id(map()) :: {:ok, String.t()} | {:error, :missing_dispute_id}
  def dispute_id(%{"data" => %{"object" => %{"id" => id}}}) when is_binary(id) and id != "" do
    {:ok, id}
  end

  def dispute_id(_payload), do: {:error, :missing_dispute_id}

  defp object_of(%{object: object}), do: object
  defp object_of(%{"object" => object}), do: object
  defp object_of(_), do: %{}

  defp fetch(data, key) when is_map(data) do
    Map.get(data, key) || Map.get(data, Atom.to_string(key))
  end

  defp fetch(_, _), do: nil

  defp id_of(%{id: id}) when is_binary(id), do: id
  defp id_of(%{"id" => id}) when is_binary(id), do: id
  defp id_of(id) when is_binary(id), do: id
  defp id_of(_), do: nil
end
