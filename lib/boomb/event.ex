defmodule Boomb.Event do
  @table_name :event
  @attributes [
    :event_id,
    :sport,
    :mid,
    :competition_id,
    :competition_name,
    :team1,
    :team2,
    :provider_id,
    :period_code,
    :inserted_at,
    :updated_at
  ]

  def create_table do
    case :mnesia.create_table(@table_name,
           attributes: @attributes,
           type: :set,
           index: [:sport],
           ram_copies: [node()]
         ) do
      {:atomic, :ok} ->
        :ok
      {:aborted, {:already_exists, @table_name}} ->
        :ok
      {:aborted, reason} ->
        raise "Failed to create Mnesia table #{@table_name}: #{inspect(reason)}"
    end
  end

  def upsert(attrs) do
    :mnesia.transaction(fn ->
      event = :mnesia.read({@table_name, attrs.event_id})
      # Ensure all fields are provided with defaults if not present
      event_id = attrs.event_id
      sport = Map.get(attrs, :sport, "unknown")
      mid = Map.get(attrs, :mid, nil)
      competition_id = Map.get(attrs, :competition_id, nil)
      competition_name = Map.get(attrs, :competition_name, nil)
      team1 = Map.get(attrs, :team1, "Unknown Team 1")
      team2 = Map.get(attrs, :team2, "Unknown Team 2")
      provider_id = Map.get(attrs, :provider_id, nil)
      period_code = Map.get(attrs, :period_code, 0)

      record = case event do
        [] ->
          # Create a new event record with defaults
          {@table_name,
           event_id,
           sport,
           mid,
           competition_id,
           competition_name,
           team1,
           team2,
           provider_id,
           period_code,
           DateTime.utc_now(),
           DateTime.utc_now()}
        [{@table_name, event_id, existing_sport, existing_mid, existing_competition_id, existing_competition_name, existing_team1, existing_team2, existing_provider_id, _existing_period_code, inserted_at, _updated_at}] ->
          # Update existing event, preserving fields unless new data is provided
          {@table_name,
           event_id,
           sport || existing_sport,
           mid || existing_mid,
           competition_id || existing_competition_id,
           competition_name || existing_competition_name,
           team1 || existing_team1,
           team2 || existing_team2,
           provider_id || existing_provider_id,
           period_code,
           inserted_at,
           DateTime.utc_now()}
      end
      :mnesia.write(record)
    end)
  end

  def delete(event_id) do
    :mnesia.transaction(fn ->
      :mnesia.delete({@table_name, event_id})
    end)
  end

  def get(event_id) do
    case :mnesia.transaction(fn ->
      :mnesia.read({@table_name, event_id})
    end) do
      {:atomic, []} ->
        {:error, :not_found}
      {:atomic, [{@table_name, event_id, sport, mid, competition_id, competition_name, team1, team2, provider_id, period_code, inserted_at, updated_at}]} ->
        {:ok, %{
          event_id: event_id,
          sport: sport,
          mid: mid,
          competition_id: competition_id,
          competition_name: competition_name,
          team1: team1,
          team2: team2,
          provider_id: provider_id,
          period_code: period_code,
          inserted_at: inserted_at,
          updated_at: updated_at
        }}
      {:aborted, reason} ->
        {:error, reason}
    end
  end

  def list_by_sport(sport) do
    case :mnesia.transaction(fn ->
      :mnesia.index_read(@table_name, sport, :sport)
      |> Enum.map(fn {@table_name, event_id, sport, mid, competition_id, competition_name, team1, team2, provider_id, period_code, inserted_at, updated_at} ->
        %{
          event_id: event_id,
          sport: sport,
          mid: mid,
          competition_id: competition_id,
          competition_name: competition_name,
          team1: team1,
          team2: team2,
          provider_id: provider_id,
          period_code: period_code,
          inserted_at: inserted_at,
          updated_at: updated_at
        }
      end)
    end) do
      {:atomic, events} -> events
      {:aborted, _reason} -> []
    end
  end

  def group_by_sport do
    case :mnesia.transaction(fn ->
      :mnesia.foldl(
        fn record, acc ->
          {@table_name, event_id, sport, mid, competition_id, competition_name, team1, team2, provider_id, period_code, inserted_at, updated_at} = record
          event = %{
            event_id: event_id,
            sport: sport,
            mid: mid,
            competition_id: competition_id,
            competition_name: competition_name,
            team1: team1,
            team2: team2,
            provider_id: provider_id,
            period_code: period_code,
            inserted_at: inserted_at,
            updated_at: updated_at
          }
          Map.update(acc, sport, [event], &[event | &1])
        end,
        %{},
        @table_name
      )
    end) do
      {:atomic, sports} -> sports
      {:aborted, _reason} -> %{}
    end
  end
end