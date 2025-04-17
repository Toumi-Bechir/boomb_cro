defmodule Boomb.SportsCache do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_sports do
    case :ets.lookup(:sports_cache, :sports) do
      [{:sports, sports}] -> sports
      [] -> %{}
    end
  end

  def update_sports(sports) do
    GenServer.cast(__MODULE__, {:update, sports})
  end

  def init(_state) do
    :ets.new(:sports_cache, [:set, :public, :named_table])
    sports = Boomb.Event.group_by_sport()
    :ets.insert(:sports_cache, {:sports, sports})
    {:ok, %{}}
  end

  def handle_cast({:update, sports}, state) do
    :ets.insert(:sports_cache, {:sports, sports})
    {:noreply, state}
  end
end