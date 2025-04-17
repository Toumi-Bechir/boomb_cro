defmodule Boomb.Hattoken do
use GenServer
  require Logger

  @token_url "http://85.217.222.218:8765/api/v1/auth/gettoken"
  @token "d306a694785d45065cb608dada5f9a88"
  # 60 minutes in milliseconds
  @refresh_interval 60 * 60 * 1000

  

  def token do
    client = Tesla.client([Tesla.Middleware.JSON])
    body = %{"apiKey" => @token}

    case Tesla.post(client, @token_url, body) do
      {:ok, %Tesla.Env{status: 200, body: %{"token" => token}}} ->
        Logger.info("Fetched new Goalserve token")
        IO.inspect token
        %{token: token}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        Logger.error("Token fetch failed: Status #{status}, Body: #{inspect(body)}")
        %{token: nil}

      {:error, reason} ->
        Logger.error("Token fetch error: #{inspect(reason)}")
        %{token: nil}
    end
  end

  
end
