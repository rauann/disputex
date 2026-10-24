defmodule Disputex.Privacy.Crypto do
  @moduledoc """
  AES-256-GCM for `pii_vault`. The key is `VAULT_KEY`, base64-encoded 32 bytes.

  Ciphertext layout is `iv (12) || tag (16) || ciphertext`. `aad` binds the
  blob to a dispute and token so rows cannot be swapped.
  """

  @iv_size 12
  @tag_size 16

  @spec encrypt(binary(), binary()) :: binary()
  def encrypt(plaintext, aad) when is_binary(plaintext) and is_binary(aad) do
    iv = :crypto.strong_rand_bytes(@iv_size)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, key!(), iv, plaintext, aad, true)

    iv <> tag <> ciphertext
  end

  @spec decrypt(binary(), binary()) ::
          {:ok, binary()} | {:error, :decrypt_failed | :invalid_ciphertext}
  def decrypt(<<iv::binary-size(@iv_size), tag::binary-size(@tag_size), ciphertext::binary>>, aad)
      when is_binary(aad) do
    case :crypto.crypto_one_time_aead(:aes_256_gcm, key!(), iv, ciphertext, aad, tag, false) do
      plaintext when is_binary(plaintext) -> {:ok, plaintext}
      :error -> {:error, :decrypt_failed}
    end
  end

  def decrypt(_ciphertext, _aad), do: {:error, :invalid_ciphertext}

  defp key! do
    case Application.fetch_env(:disputex, :vault_key) do
      {:ok, encoded} when is_binary(encoded) ->
        case Base.decode64(encoded) do
          {:ok, <<key::binary-size(32)>>} -> key
          _ -> raise ArgumentError, "VAULT_KEY must be base64-encoded 32 bytes"
        end

      _ ->
        raise ArgumentError, "VAULT_KEY is not set"
    end
  end
end
