defmodule Boomb.OddsThrottler do
  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def update_odds(event_id, odds_data), do: GenServer.cast(__MODULE__, {:update, event_id, odds_data})
  def update_odds_foroverview(event_id, odds_data), do: GenServer.cast(__MODULE__, {:update_overview, event_id, odds_data})

  def init(_), do: {:ok, %{}}

  def handle_cast({:update, event_id, odds_data}, state) do
    case Map.get(state, event_id) do
      nil ->
        broadcast(event_id, odds_data)
        Process.send_after(self(), {:clear, event_id}, 1000) # Throttle to 1 second
        {:noreply, Map.put(state, event_id, odds_data)}
      _ ->
        {:noreply, state} # Ignore until throttle clears
    end
  end

  def handle_cast({:update_overview, event_id, odds_data}, state) do
    #IO.puts "+++++++++ handle_cast  update_overview ++++++++++++"
    case Map.get(state, event_id) do
      nil ->
        broadcast_overview(event_id, odds_data)
        Process.send_after(self(), {:clear, event_id}, 1000) # Throttle to 1 second
        {:noreply, Map.put(state, event_id, odds_data)}
      _ ->
        {:noreply, state} # Ignore until throttle clears
    end
  end

  def handle_info({:clear, event_id}, state) do
    {:noreply, Map.delete(state, event_id)}
  end

  defp broadcast_overview(event_id, odds_data) do
    sport = odds_data.sport
    Phoenix.PubSub.broadcast(Boomb.PubSub, "odds_update_overview:#{sport}:#{event_id}", %{overview_data: odds_data})
  end
  defp broadcast(event_id, odds_data) do
    sport = odds_data.sport
    IO.puts "+++++++++ broadcsting    handle_cast  update_overview ++++++++++++"
    Phoenix.PubSub.broadcast(Boomb.PubSub, "odds_update:#{sport}:#{event_id}", odds_data)
  end
  
end