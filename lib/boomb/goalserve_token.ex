defmodule Boomb.GoalserveToken do
  use GenServer
  require Logger

  @token_url "http://85.217.222.218:8765/api/v1/auth/gettoken"
  @refresh_interval 60 * 60 * 1000 # 60 minutes in milliseconds

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_token do
    GenServer.call(__MODULE__, :get_token)
  end

  def init(_state) do
    schedule_token_refresh()
    {:ok, fetch_token()}
  end

  def handle_call(:get_token, _from, state) do
    {:reply, state[:token], state}
  end

  def handle_info(:refresh_token, _state) do
    schedule_token_refresh()
    {:noreply, fetch_token()}
  end

  defp fetch_token do
    client = Tesla.client([Tesla.Middleware.JSON])
    body = %{"apiKey" => Application.get_env(:boomb, :goalserve_api_key)}

    case Tesla.post(client, @token_url, body) do
      {:ok, %Tesla.Env{status: 200, body: %{"token" => token}}} ->
        Logger.info("Fetched new Goalserve token")
        %{token: token}
      {:ok, %Tesla.Env{status: status, body: body}} ->
        Logger.error("Token fetch failed: Status #{status}, Body: #{inspect(body)}")
        %{token: nil}
      {:error, reason} ->
        Logger.error("Token fetch error: #{inspect(reason)}")
        %{token: nil}
    end
  end

  defp schedule_token_refresh do
    Process.send_after(self(), :refresh_token, @refresh_interval)
  end
end