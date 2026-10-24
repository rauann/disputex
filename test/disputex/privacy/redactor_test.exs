defmodule Disputex.Privacy.RedactorTest do
  use Disputex.DataCase, async: true
  use ExUnitProperties

  alias Disputex.Privacy.{Redactor, VaultEntry}

  property "redaction hides pii, ciphertext does not contain it, and rehydrate is exact" do
    check all(fixture <- pii_fixture(), max_runs: 40) do
      dispute = dispute_fixture()

      assert {:ok, redacted} =
               Redactor.redact(fixture.text, dispute_id: dispute.id, names: fixture.names)

      for secret <- fixture.secrets do
        refute String.contains?(redacted, secret)
      end

      entries = Repo.all(from entry in VaultEntry, where: entry.dispute_id == ^dispute.id)
      stored = Enum.map_join(entries, & &1.ciphertext)

      for secret <- fixture.secrets do
        refute String.contains?(stored, secret)
      end

      assert {:ok, again} =
               Redactor.redact(redacted, dispute_id: dispute.id, names: fixture.names)

      assert again == redacted

      assert {:ok, restored} = Redactor.rehydrate(redacted, dispute.id)
      assert restored == fixture.text
    end
  end

  test "amounts and dates are not treated as phone numbers" do
    dispute = dispute_fixture()
    text = "amount=41800 due=2026-12-01 currency=usd"

    assert {:ok, ^text} = Redactor.redact(text, dispute_id: dispute.id, names: [])
  end

  test "the same value always reuses a token" do
    dispute = dispute_fixture()
    text = "ada@example.test and ada@example.test"

    assert {:ok, redacted} = Redactor.redact(text, dispute_id: dispute.id, names: [])
    assert redacted == "<EMAIL_1> and <EMAIL_1>"

    assert {:ok, "ada@example.test and ada@example.test"} =
             Redactor.rehydrate(redacted, dispute.id)
  end

  defp pii_fixture do
    gen all(
          name <- name_gen(),
          email <- email_gen(),
          phone <- phone_gen(),
          note <- string(?a..?z, max_length: 20)
        ) do
      text = "Hello #{name}. Reach #{email} or #{phone}. Note #{note}. Again #{email}."

      %{text: text, names: [name], secrets: [name, email, phone]}
    end
  end

  defp name_gen do
    gen all(
          first <- string(?a..?z, min_length: 4, max_length: 8),
          last <- string(?a..?z, min_length: 4, max_length: 8)
        ) do
      String.capitalize(first) <> " " <> String.capitalize(last)
    end
  end

  defp email_gen do
    gen all(
          local <- string(:alphanumeric, min_length: 3, max_length: 10),
          host <- string(?a..?z, min_length: 3, max_length: 8)
        ) do
      String.downcase(local) <> "@" <> host <> ".test"
    end
  end

  defp phone_gen do
    gen all(
          area <- string(?0..?9, length: 3),
          exchange <- string(?0..?9, length: 3),
          line <- string(?0..?9, length: 4),
          style <- integer(0..1)
        ) do
      case style do
        0 -> "(#{area}) #{exchange}-#{line}"
        1 -> "+1 #{area} #{exchange} #{line}"
      end
    end
  end
end
