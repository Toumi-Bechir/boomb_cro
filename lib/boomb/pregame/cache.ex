defmodule Boomb.Pregame.Cache do
  use GenServer
  require Logger

  @tables %{
    "soccer" => :PregameSoccer,
    "basket" => :PregameBasket,
    "tennis" => :PregameTennis,
    "hockey" => :PregameHockey,
    "handball" => :PregameHandball,
    "volleyball" => :PregameVolleyball,
    "football" => :PregameFootball,
    "baseball" => :PregameBaseball,
    "cricket" => :PregameCricket,
    "rugby" => :PregameRugby,
    "rugbyleague" => :PregameRugbyLeague,
    "boxing" => :PregameBoxing,
    "esports" => :PregameEsports,
    "futsal" => :PregameFutsal,
    "mma" => :PregameMMA,
    "table_tennis" => :PregameTableTennis,
    "golf" => :PregameGolf,
    "darts" => :PregameDarts
  }

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def init(state) do
    Logger.info("Starting Pregame Cache")
    schedule_cleanup()
    {:ok, state}
  end

  def store(sport, data) do
    GenServer.cast(__MODULE__, {:store, sport, data})
  end

  def list_sports, do: Map.keys(@tables)

  def get_countries_by_sport(sport, filter) do
    table = Map.get(@tables, sport)
    now = System.system_time(:millisecond)
    :mnesia.transaction(fn ->
      :mnesia.match_object(table, {table, :_, :_, :_, :_, :_, :_, :_}, :read)
      |> Enum.filter(fn {_, _, start_time, _, _, _, _, _} ->
        start_time > now and matches_filter?(start_time, now, filter)
      end)
      |> Enum.group_by(fn {_, _, _, _, %{country: country}, _, _, _} -> country end)
      |> Enum.map(fn {country, matches} ->
        leagues = Enum.map(matches, fn {_, _, _, _, %{league: league}, _, _, _} -> league end) |> Enum.uniq()
        {country, leagues}
      end)
    end) |> elem(1)
  end

  def get_matches_by_leagues(leagues, filter) do
    now = System.system_time(:millisecond)
    Enum.flat_map(@tables, fn {sport, table} ->
      :mnesia.transaction(fn ->
        :mnesia.match_object(table, {table, :_, :_, :_, :_, :_, :_, :_}, :read)
        |> Enum.filter(fn {_, _, start_time, _, %{country: country, league: league}, _, _, _} ->
          start_time > now and matches_filter?(start_time, now, filter) and {country, league} in leagues
        end)
      end) |> elem(1)
    end)
    |> Enum.group_by(fn {_, _, _, _, %{country: country}, _, _, _} -> country end)
    |> Enum.map(fn {country, matches} ->
      leagues = Enum.group_by(matches, fn {_, _, _, _, %{league: league}, _, _, _} -> league end)
      {country, leagues}
    end)
  end

  def get_match(sport, match_id) do
    table = Map.get(@tables, sport)
    now = System.system_time(:millisecond)
    :mnesia.transaction(fn ->
      case :mnesia.read(table, match_id) do
        [match = {_, _, start_time, _, _, _, _, _}] when start_time > now -> {:ok, match}
        _ -> {:error, :not_found}
      end
    end)
  end
#{"scores": {"sport": "table_tennis", "ts": "1744994932", "categories": [...]}}
  def handle_cast({:store, sport, %{"scores" => %{"category" => categories}}}, state) do
    store_categories(sport, categories)
    {:noreply, state}
  end

  #def handle_cast({:store, sport, %{"category" => categories}}, state) do
    def handle_cast({:store, sport,data}, state) do
    store_categories(sport, data["categories"])
    {:noreply, state}
  end

  #def handle_cast({:store, sport, data}, state) do
  #  Logger.error("Unexpected data structure for #{sport}: #{inspect(Map.keys(data), limit: 10)}")
  #  {:noreply, state}
  #end

  defp store_categories(sport, categories) do
    table = Map.get(@tables, sport)
    :mnesia.transaction(fn ->
      Enum.each(categories, fn category ->
        country = category["@name"] || category["name"] || "Unknown"
        matches = case category["matches"]["match"] do
          match when is_map(match) -> [match]
          matches when is_list(matches) -> matches
          _ -> []
        end
        Enum.each(matches, fn match ->
          match_id = match["@id"] || match["id"]
          start_time = parse_timestamp(Map.get(match, "date", match["@date"] || "1970-01-01"))
          teams = %{
            home: match["localteam"]["@name"] || match["localteam"]["name"],
            away: match["awayteam"]["@name"] || match["awayteam"]["name"]
          }
          league = %{country: country, league: country}
          odds = parse_odds(match["odds"]["type"] || [])
          stats = Map.get(match, "stats", %{})
          ts = match["odds"]["@ts"] || match["odds"]["ts"] || "0"
          :mnesia.write(table, {table, match_id, start_time, teams, league, odds, ts, stats}, :write)
        end)
      end)
    end)
  end

  def handle_info(:cleanup, state) do
    four_hours_ago = System.system_time(:millisecond) - 4 * 60 * 60 * 1000
    Enum.each(@tables, fn {_, table} ->
      :mnesia.transaction(fn ->
        :mnesia.foldl(
          fn {_, id, start_time, _, _, _, _, _}, acc ->
            if start_time < four_hours_ago do
              :mnesia.delete({table, id})
            end
            acc
          end,
          nil,
          table
        )
      end)
    end)
    schedule_cleanup()
    {:noreply, state}
  end

  defp parse_timestamp(date_str) when is_binary(date_str) do
    case date_str do
      # Handle "DD.MM.YYYY" format (e.g., "23.08.2025")
      <<d1, d2, ?., m1, m2, ?., y1, y2, y3, y4>> ->
        date = "#{y1}#{y2}#{y3}#{y4}-#{m1}#{m2}-#{d1}#{d2}T00:00:00Z"
        case DateTime.from_iso8601(date) do
          {:ok, dt, _} -> DateTime.to_unix(dt, :millisecond)
          _ -> 0
        end
      # Handle "MMM DD" format (e.g., "Apr 18")
      _ ->
        case Regex.run(~r/(\w{3}) (\d{1,2})/, date_str) do
          [_, month, day] ->
            year = Date.utc_today().year
            date = "#{year}-#{month_to_number(month)}-#{String.pad_leading(day, 2, "0")}T00:00:00Z"
            case DateTime.from_iso8601(date) do
              {:ok, dt, _} -> DateTime.to_unix(dt, :millisecond)
              _ -> 0
            end
          _ ->
            Logger.warn("Invalid date format: #{date_str}")
            0
        end
    end
  end
  defp parse_timestamp(_), do: 0

  defp month_to_number(month) do
    case String.downcase(month) do
      "jan" -> "01"
      "feb" -> "02"
      "mar" -> "03"
      "apr" -> "04"
      "may" -> "05"
      "jun" -> "06"
      "jul" -> "07"
      "aug" -> "08"
      "sep" -> "09"
      "oct" -> "10"
      "nov" -> "11"
      "dec" -> "12"
      _ -> "01"
    end
  end

  defp parse_odds(odds_data) when is_list(odds_data) do
    odds_data
    |> Enum.map(fn %{"@value" => market, "bookmaker" => bookmakers} ->
      values = Enum.flat_map(bookmakers, fn bm ->
        Enum.map(bm["odd"], fn %{"@name" => name, "@value" => value} ->
          {name, parse_float(value)}
        end)
      end) |> Enum.uniq_by(fn {name, _} -> name end) |> Map.new()
      {market, values}
    end)
    |> Map.new()
  end
  defp parse_odds(_), do: %{}

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> 0.0
    end
  end
  defp parse_float(_), do: 0.0

  defp matches_filter?(start_time, now, :all), do: true
  defp matches_filter?(start_time, now, :today) do
    {today, _} = DateTime.from_unix!(now, :millisecond) |> DateTime.to_date() |> Date.to_erl()
    {match_day, _} = DateTime.from_unix!(start_time, :millisecond) |> DateTime.to_date() |> Date.to_erl()
    today == match_day
  end
  defp matches_filter?(start_time, now, hours) when is_integer(hours) do
    start_time <= now + hours * 60 * 60 * 1000
  end

  defp schedule_cleanup, do: Process.send_after(self(), :cleanup, 3_600_000) # 1 hour
end
