# lib/boomb/storage/mnesia_setup.ex
defmodule Boomb.Storage.MnesiaSetup do
  @moduledoc """
  Initializes Mnesia database with sharded tables for each sport to handle high match volume.
  """

  alias :mnesia, as: Mnesia

  @sports ["soccer", "basket", "tennis", "baseball", "amfootball", "hockey", "volleyball"]

  # Define the match struct
  defstruct id: nil, sport: nil, competition: nil, team1: nil, team2: nil, score: nil, time: nil, stats: nil, odds: nil, status: nil, events: nil, heatmap: nil

  def init do
    # Create Mnesia schema and start Mnesia
    Mnesia.create_schema([node()])
    Mnesia.start()

    # Create a table for each sport
    Enum.each(@sports, fn sport ->
      table_name = String.to_atom("match_#{sport}")
      Mnesia.create_table(table_name, [
        attributes: [:id, :sport, :competition, :team1, :team2, :score, :time, :stats, :odds, :status, :events, :heatmap],
        disc_copies: [node()],
        type: :set,
        record_name: __MODULE__ # Use the struct as the record name
      ])
    end)

    # Wait for all tables to be ready
    Mnesia.wait_for_tables(Enum.map(@sports, &String.to_atom("match_#{&1}")), 5000)
  end

  def write(match) do
    table_name = String.to_atom("match_#{match.sport}")
    :mnesia.transaction(fn ->
      :mnesia.write({table_name, match.id, match.sport, match.competition, match.team1, match.team2, match.score, match.time, match.stats, match.odds, match.status, match.events, match.heatmap})
    end)
  end

  def read(sport, match_id) do
    table_name = String.to_atom("match_#{sport}")
    :mnesia.transaction(fn ->
      case :mnesia.read({table_name, match_id}) do
        [record] ->
          {:ok, struct(__MODULE__, Map.from_tuple(record))}
        [] ->
          :error
      end
    end)
  end

  def fetch_all(sport) do
    table_name = String.to_atom("match_#{sport}")
    :mnesia.transaction(fn ->
      :mnesia.foldl(
        fn record, acc ->
          [struct(__MODULE__, Map.from_tuple(record)) | acc]
        end,
        [],
        table_name
      )
    end)
  end
end