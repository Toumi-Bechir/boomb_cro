defmodule Boomb.OddsCache do
  def start_link(_opts) do
    # Clear any existing data to ensure consistency
    if :ets.info(:odds_cache) != :undefined do
      :ets.delete(:odds_cache)
    end
    :ets.new(:odds_cache, [:set, :public, :named_table])
    {:ok, self()}
  end

  def update_odds(event_id, odds_data) do
    :ets.insert(:odds_cache, {event_id, odds_data})
  end

  def get_odds(event_id) do
    case :ets.lookup(:odds_cache, event_id) do
      [{_id, odds_data}] -> {:ok, odds_data}
      [] -> {:error, :not_found}
    end
  end

  def get_all_odds do
    :ets.foldl(fn {event_id, odds_data}, acc ->
      Map.put(acc, event_id, odds_data)
    end, %{}, :odds_cache)
  end
end