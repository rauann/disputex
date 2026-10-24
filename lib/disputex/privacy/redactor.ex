defmodule Disputex.Privacy.Redactor do
  @moduledoc """
  Replaces emails, phone numbers, and known names with tokens such as `<EMAIL_1>`.

  The original value is stored in `pii_vault`, encrypted. `rehydrate/2` is the
  inverse for a dispute. Token syntax (`<EMAIL_N>`, `<PHONE_N>`, `<NAME_N>`) is
  reserved and is not treated as source text.
  """

  import Ecto.Query

  alias Disputex.Privacy.{Crypto, VaultEntry}
  alias Disputex.Repo

  @email ~r/[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/
  @phone ~r/(?:\+\d{1,3}[\s.\-]?)?(?:\(\d{3}\)[\s.\-]?|\d{3}[\s.\-])\d{3}[\s.\-]\d{4}/
  @token ~r/<(EMAIL|PHONE|NAME)_(\d+)>/

  @type option :: {:dispute_id, Ecto.UUID.t()} | {:names, [String.t()]}

  @spec redact(String.t(), [option()]) :: {:ok, String.t()} | {:error, term()}
  def redact(text, opts) when is_binary(text) and is_list(opts) do
    dispute_id = Keyword.fetch!(opts, :dispute_id)
    names = Keyword.get(opts, :names, [])

    Repo.transaction(fn ->
      case load_state(dispute_id) do
        {:ok, state} ->
          {redacted, state} = transform(text, names, state)
          persist_fresh!(dispute_id, state.fresh)
          redacted

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  @spec rehydrate(String.t(), Ecto.UUID.t()) :: {:ok, String.t()} | {:error, term()}
  def rehydrate(text, dispute_id) when is_binary(text) do
    entries = Repo.all(from entry in VaultEntry, where: entry.dispute_id == ^dispute_id)

    Enum.reduce_while(entries, {:ok, %{}}, fn entry, {:ok, acc} ->
      case Crypto.decrypt(entry.ciphertext, aad(dispute_id, entry.token)) do
        {:ok, plaintext} -> {:cont, {:ok, Map.put(acc, entry.token, plaintext)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, tokens} -> {:ok, restore(text, tokens)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp transform(text, names, state) do
    matches =
      (scan(text, @email, :email) ++ scan(text, @phone, :phone) ++ name_matches(text, names))
      |> Enum.sort_by(fn {start, length, _kind, _value} -> {start, -length} end)
      |> drop_overlaps()

    stitch(text, matches, state)
  end

  defp scan(text, regex, kind) do
    regex
    |> Regex.scan(text, return: :index)
    |> Enum.map(fn [{start, length}] ->
      {start, length, kind, binary_part(text, start, length)}
    end)
  end

  defp name_matches(text, names) do
    names
    |> Enum.filter(&(is_binary(&1) and String.length(String.trim(&1)) >= 2))
    |> Enum.uniq()
    |> Enum.sort_by(&String.length/1, :desc)
    |> Enum.flat_map(fn name ->
      regex = Regex.compile!("(?<![\\p{L}])#{Regex.escape(name)}(?![\\p{L}])", [:unicode])
      scan(text, regex, :name)
    end)
  end

  defp drop_overlaps(matches) do
    {kept, _cursor} =
      Enum.reduce(matches, {[], 0}, fn {start, length, _kind, _value} = match, {kept, cursor} ->
        if start >= cursor do
          {[match | kept], start + length}
        else
          {kept, cursor}
        end
      end)

    Enum.reverse(kept)
  end

  defp stitch(text, matches, state) do
    {iodata, state, position} =
      Enum.reduce(matches, {[], state, 0}, fn {start, length, kind, value},
                                              {acc, state, position} ->
        prefix = binary_part(text, position, start - position)
        {token, state} = token_for(state, kind, value)
        {[acc, prefix, token], state, start + length}
      end)

    rest = binary_part(text, position, byte_size(text) - position)
    {IO.iodata_to_binary([iodata, rest]), state}
  end

  defp token_for(state, kind, value) do
    case Map.get(state.tokens, {kind, value}) do
      nil ->
        number = Map.get(state.counters, kind, 0) + 1
        token = "<#{label(kind)}_#{number}>"

        state = %{
          state
          | tokens: Map.put(state.tokens, {kind, value}, token),
            counters: Map.put(state.counters, kind, number),
            fresh: [{token, value} | state.fresh]
        }

        {token, state}

      token ->
        {token, state}
    end
  end

  defp label(:email), do: "EMAIL"
  defp label(:phone), do: "PHONE"
  defp label(:name), do: "NAME"

  defp load_state(dispute_id) do
    entries = Repo.all(from entry in VaultEntry, where: entry.dispute_id == ^dispute_id)

    Enum.reduce_while(entries, {:ok, empty_state()}, fn entry, {:ok, state} ->
      case Crypto.decrypt(entry.ciphertext, aad(dispute_id, entry.token)) do
        {:ok, plaintext} -> {:cont, {:ok, remember(state, entry.token, plaintext)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp remember(state, token, plaintext) do
    case Regex.run(@token, token) do
      [_, label, number] ->
        kind = kind(label)
        count = String.to_integer(number)

        %{
          state
          | tokens: Map.put(state.tokens, {kind, plaintext}, token),
            counters: Map.update(state.counters, kind, count, &max(&1, count))
        }

      _ ->
        state
    end
  end

  defp kind("EMAIL"), do: :email
  defp kind("PHONE"), do: :phone
  defp kind("NAME"), do: :name

  defp empty_state, do: %{tokens: %{}, counters: %{}, fresh: []}

  defp persist_fresh!(dispute_id, fresh) do
    Enum.each(fresh, fn {token, plaintext} ->
      %VaultEntry{}
      |> VaultEntry.changeset(%{
        dispute_id: dispute_id,
        token: token,
        ciphertext: Crypto.encrypt(plaintext, aad(dispute_id, token))
      })
      |> Repo.insert!()
    end)
  end

  defp restore(text, tokens) do
    Regex.replace(@token, text, fn token, _label, _number ->
      Map.get(tokens, token, token)
    end)
  end

  defp aad(dispute_id, token), do: dispute_id <> ":" <> token
end
