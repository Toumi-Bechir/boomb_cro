defmodule Boomb.GoalserveWebsocketSupervisor do
  use GenServer
  require Logger

  # Client API
  def start_link(_arg) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  # Server Callbacks
  def init(:ok) do
    # Start the Registry separately
    {:ok, _} = Registry.start_link(keys: :unique, name: Boomb.Registry)

    # Initialize the DynamicSupervisor
    children = []
    opts = [strategy: :one_for_one]
    {:ok, sup_pid} = DynamicSupervisor.start_link(opts)

    # Send a message to self to start WebSocket clients after initialization
    Process.send(self(), :start_websockets, [])

    # Initialize state with supervisor PID and an empty list of started sports
    {:ok, %{supervisor: sup_pid, started_sports: []}}
  end

  def handle_info(:start_websockets, state) do
    sports = ["soccer", "basket", "tennis", "baseball", "amfootball", "hockey", "volleyball"]
    new_started_sports = Enum.reduce(sports, state.started_sports, fn sport, acc ->
      if sport in acc do
        acc
      else
        Logger.info("Starting WebSocket client for #{sport}")
        start_websocket(state.supervisor, sport)
        [sport | acc]
      end
    end)
    {:noreply, %{state | started_sports: new_started_sports}}
  end

  # Private Functions
  defp start_websocket(supervisor, sport) do
    child_spec = {Boomb.GoalserveWebsocket, sport}
    case DynamicSupervisor.start_child(supervisor, child_spec) do
      {:ok, _pid} ->
        Logger.info("Started WebSocket client for #{sport}")
      {:error, reason} ->
        Logger.error("Failed to start WebSocket client for #{sport}: #{inspect(reason)}")
    end
  end
end