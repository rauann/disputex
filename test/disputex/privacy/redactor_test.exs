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

      for kept <- fixture.kept do
        assert String.contains?(redacted, kept)
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

  test "international numbers are redacted and lookalikes are kept" do
    dispute = dispute_fixture()

    text =
      "br +55 19 97106-7042 nl +31 6 12345678 uk +44 20 7946 0958 pt +351 912 345 678 " <>
        "us (415) 555-0100 dashed 415-555-0199 compact +5519971067042 " <>
        "ref BK-1042 amount=41800 due=2026-12-01 ip 203.0.113.5 " <>
        "at 2026-09-21T14:13:20.000000Z offset +00:00"

    assert {:ok, redacted} = Redactor.redact(text, dispute_id: dispute.id, names: [])

    for secret <- [
          "+55 19 97106-7042",
          "+31 6 12345678",
          "+44 20 7946 0958",
          "+351 912 345 678",
          "(415) 555-0100",
          "415-555-0199",
          "+5519971067042"
        ] do
      refute redacted =~ secret
    end

    for kept <- [
          "BK-1042",
          "amount=41800",
          "2026-12-01",
          "203.0.113.5",
          "2026-09-21T14:13:20.000000Z",
          "+00:00"
        ] do
      assert redacted =~ kept
    end

    assert {:ok, ^text} = Redactor.rehydrate(redacted, dispute.id)
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
      text =
        "Hello #{name}. Reach #{email} or #{phone}. Note #{note}. Again #{email}. " <>
          "ref BK-1042 amount=41800 due=2026-12-01 ip 203.0.113.5 at 2026-09-21T14:13:20.000000Z"

      %{
        text: text,
        names: [name],
        secrets: [name, email, phone],
        kept: [
          "BK-1042",
          "amount=41800",
          "due=2026-12-01",
          "203.0.113.5",
          "2026-09-21T14:13:20.000000Z"
        ]
      }
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
    one_of([us_phone_gen(), intl_phone_gen()])
  end

  defp us_phone_gen do
    gen all(
          area <- string(?0..?9, length: 3),
          exchange <- string(?0..?9, length: 3),
          line <- string(?0..?9, length: 4),
          style <- integer(0..2)
        ) do
      case style do
        0 -> "(#{area}) #{exchange}-#{line}"
        1 -> "+1 #{area} #{exchange} #{line}"
        2 -> "#{area}-#{exchange}-#{line}"
      end
    end
  end

  defp intl_phone_gen do
    gen all(
          cc <- string(?1..?9, length: 1),
          cc_rest <- string(?0..?9, max_length: 2),
          subscriber <- string(?0..?9, min_length: 6, max_length: 12),
          sep <- member_of([" ", "-", ".", ""])
        ) do
      digits = String.slice(cc <> cc_rest <> subscriber, 0, 15)
      format_intl(digits, sep)
    end
  end

  defp format_intl(digits, "") do
    "+" <> digits
  end

  defp format_intl(digits, sep) do
    grouped =
      digits
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map_join(sep, &Enum.join/1)

    "+" <> grouped
  end
end
