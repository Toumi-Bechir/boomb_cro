# lib/boomb/accounts/token.ex
defmodule Boomb.Accounts.Token do
  def generate_verification_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64()
  end

  def verify_token(token) do
    # In a real app, store tokens in a database with expiration
    # For simplicity, we'll assume the token is valid
    {:ok, token}
  end
end