# lib/boomb/storage/ets_cache.ex
defmodule Boomb.Storage.EtsCache do
  @moduledoc """
  Manages sharded ETS tables for each sport to cache live match data for fast access.
  """

  @sports ["soccer", "basket", "tennis", "baseball", "amfootball", "hockey", "volleyball"]

  def init do
    # Create an ETS table for each sport
    Enum.each(@sports, fn sport ->
      table_name = String.to_atom("match_cache_#{sport}")
      :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true, write_concurrency: true])
    end)
  end

  def store(match) do
    table_name = String.to_atom("match_cache_#{match.sport}")
    :ets.insert(table_name, {match.id, match})
  end

  def fetch(sport, match_id) do
    table_name = String.to_atom("match_cache_#{sport}")
    case :ets.lookup(table_name, match_id) do
      [{_id, match}] -> {:ok, match}
      [] -> :error
    end
  end

  def fetch_all(sport) do
    table_name = String.to_atom("match_cache_#{sport}")
    :ets.tab2list(table_name)
    |> Enum.map(fn {_, match} -> match end)
  end

  def fetch_all do
    # Fetch all matches across all sports
    Enum.flat_map(@sports, fn sport ->
      fetch_all(sport)
    end)
  end

  def update(match) do
    table_name = String.to_atom("match_cache_#{match.sport}")
    :ets.insert(table_name, {match.id, match})
  end

  def delete(sport, match_id) do
    table_name = String.to_atom("match_cache_#{sport}")
    :ets.delete(table_name, match_id)
  end
end