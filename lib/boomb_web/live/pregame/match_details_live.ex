defmodule BoombWeb.Pregame.MatchDetailsLive do
  use BoombWeb, :live_view
  require Logger

  def mount(params, _session, socket) do
    sport = String.to_atom(params["sport"] || "soccer")
    filter = String.to_atom(params["filter"] || "today")
    match_id = params["match_id"]
    leagues = parse_leagues(params["leagues"])

    Logger.debug("MatchDetailsLive mount with params: #{inspect(params)}")
    Logger.debug("Parsed leagues: #{inspect(leagues)}")

    Phoenix.PubSub.subscribe(Boomb.PubSub, "pregame:#{sport}")

    # Fetch matches to populate the left-side list
    matches = fetch_matches(sport, filter, leagues)

    # Find the selected match or default to the first match
    selected_match =
      case find_match_by_id(matches, match_id) do
        match when is_map(match) -> match
        nil ->
          case matches do
            [{_country, [{_league, [{_start_time, [match | _]}]}]} | _] -> match
            _ -> nil
          end
      end

    # Parse the current score for Asian Handicap (e.g., "0-0")
    current_score =
      if selected_match && Map.has_key?(selected_match, :ht) && selected_match.ht[:score] != "" do
        selected_match.ht[:score]
      else
        "0-0"
      end

    socket =
      socket
      |> assign(:sport, sport)
      |> assign(:filter, filter)
      |> assign(:leagues, leagues)
      |> assign(:matches, matches)
      |> assign(:selected_match, selected_match)
      |> assign(:match_id, match_id)
      |> assign(:left_menu_visible, true)
      |> assign(:current_score, current_score)
      |> assign_market_toggles()

    {:ok, socket}
  end

  def handle_event("select_match", %{"match_id" => match_id}, socket) do
    selected_match =
      case find_match_by_id(socket.assigns.matches, match_id) do
        match when is_map(match) -> match
        nil -> socket.assigns.selected_match
      end

    # Update current score when a new match is selected
    current_score =
      if selected_match && Map.has_key?(selected_match, :ht) && selected_match.ht[:score] != "" do
        selected_match.ht[:score]
      else
        "0-0"
      end

    socket =
      socket
      |> assign(:selected_match, selected_match)
      |> assign(:match_id, match_id)
      |> assign(:current_score, current_score)

    {:noreply, socket}
  end

  def handle_event("toggle_market", %{"market" => market_name}, socket) do
    market_key = String.to_atom("market_#{market_name}")
    current_state = Map.get(socket.assigns, market_key, true)
    socket = assign(socket, market_key, !current_state)
    {:noreply, socket}
  end

  def handle_event("toggle_left_menu", _params, socket) do
    socket = assign(socket, :left_menu_visible, !socket.assigns.left_menu_visible)
    {:noreply, socket}
  end

  def handle_info({:update, sport}, socket) do
    if sport == socket.assigns.sport do
      matches = fetch_matches(sport, socket.assigns.filter, socket.assigns.leagues)
      selected_match =
        case find_match_by_id(matches, socket.assigns.match_id) do
          match when is_map(match) -> match
          nil ->
            case matches do
              [{_country, [{_league, [{_start_time, [match | _]}]}]} | _] -> match
              _ -> nil
            end
        end

      current_score =
        if selected_match && Map.has_key?(selected_match, :ht) && selected_match.ht[:score] != "" do
          selected_match.ht[:score]
        else
          "0-0"
        end

      socket =
        socket
        |> assign(:matches, matches)
        |> assign(:selected_match, selected_match)
        |> assign(:current_score, current_score)
        |> assign_market_toggles()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp assign_market_toggles(socket) do
    if socket.assigns.selected_match do
      markets = Map.keys(socket.assigns.selected_match.markets)
      Enum.reduce(markets, socket, fn market, acc ->
        assign(acc, String.to_atom("market_#{market}"), true)
      end)
    else
      socket
    end
  end

  defp find_match_by_id(matches, match_id) do
    Enum.find_value(matches, fn {country, leagues} ->
      Enum.find_value(leagues, fn {league, time_groups} ->
        Enum.find_value(time_groups, fn {start_time, match_list} ->
          Enum.find(match_list, fn match -> match.match_id == match_id end)
        end)
      end)
    end)
  end

  defp parse_leagues(leagues) when is_binary(leagues) do
    case String.split(leagues, ":", parts: 2) do
      [country, league_name] -> [{normalize_country(country), normalize_league_name(league_name)}]
      _ ->
        Logger.warning("Invalid league format: #{inspect(leagues)}")
        []
    end
  end

  defp parse_leagues(leagues) when is_list(leagues) do
    leagues
    |> Enum.flat_map(fn league ->
      case String.split(league, ":", parts: 2) do
        [country, league_name] -> [{normalize_country(country), normalize_league_name(league_name)}]
        _ ->
          Logger.warning("Invalid league format in list: #{inspect(league)}")
          []
      end
    end)
    |> Enum.uniq()
  end

  defp parse_leagues(nil) do
    []
  end

  defp parse_leagues(other) do
    Logger.warning("Invalid leagues parameter: #{inspect(other)}")
    []
  end

  defp normalize_league_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp normalize_league_name(_), do: ""

  defp normalize_country(country) when is_binary(country) do
    country
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp normalize_country(_), do: ""

  defp fetch_matches(sport, filter, leagues) do
    table = String.to_atom("pregame_#{sport}")
    now = System.system_time(:second)
    filter_time =
      case filter do
        :one_hour -> now + 1 * 3600 + 60
        :three_hours -> now + 3 * 3600 + 60
        :six_hours -> now + 6 * 3600 + 60
        :twelve_hours -> now + 12 * 3600 + 60
        :today ->
          case DateTime.from_unix(now) do
            {:ok, datetime} ->
              date = DateTime.to_date(datetime)
              case NaiveDateTime.new(date, ~T[23:59:59.999999]) do
                {:ok, naive_end_of_day} ->
                  case DateTime.from_naive(naive_end_of_day, "Etc/UTC") do
                    {:ok, end_of_day} ->
                      DateTime.to_unix(end_of_day, :second) + 60
                    {:error, reason} ->
                      Logger.error("Failed to convert end of day to DateTime: #{inspect(reason)}")
                      now + 48 * 3600
                  end
                {:error, reason} ->
                  Logger.error("Failed to create end of day NaiveDateTime: #{inspect(reason)}")
                  now + 48 * 3600
              end
            {:error, reason} ->
              Logger.error("Failed to compute end of day: #{inspect(reason)}")
              now + 48 * 3600
          end
        :all -> now + 365 * 24 * 3600 + 60
      end

    Logger.debug("Fetching matches for sport: #{sport}, filter: #{filter}, leagues: #{inspect(leagues)}")

    matches =
      try do
        case :mnesia.table_info(table, :all) do
          {:undefined, _} ->
            Logger.error("Table #{table} does not exist")
            []
          info ->
            expected_attributes = [:match_id, :start_time, :team1_name, :team2_name, :country, :league, :markets, :stats, :updated_at]
            actual_attributes = Keyword.get(info, :attributes, [])
            unless actual_attributes == expected_attributes do
              Logger.error("Table #{table} has incorrect schema. Expected: #{inspect(expected_attributes)}, Got: #{inspect(actual_attributes)}")
              []
            else
              # Log stored country-league pairs
              :mnesia.transaction(fn ->
                :mnesia.select(table, [
                  {{table, :_, :_, :_, :_, :"$5", :"$6", :_, :_, :_},
                   [],
                   [{{:"$5", :"$6"}}]}
                ])
              end)
              |> case do
                {:atomic, stored_pairs} ->
                  Logger.debug("Stored country-league pairs in #{table}: #{inspect(Enum.uniq(stored_pairs))}")
                {:aborted, reason} ->
                  Logger.error("Failed to fetch country-league pairs from #{table}: #{inspect(reason)}")
              end

              # Query for each country-league pair separately and combine results
              :mnesia.transaction(fn ->
                results =
                  Enum.flat_map(leagues, fn {country, league} ->
                    match_spec = [
                      {{table, :"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :_, :_},
                       [{:>, :"$2", now}, {:<, :"$2", filter_time}, {:==, :"$5", country}, {:==, :"$6", league}],
                       [{{:"$5", :"$6", :"$2", :"$1", :"$3", :"$4", :"$7"}}]}
                    ]
                    Logger.debug("Match specification for country: #{country}, league: #{league}: #{inspect(match_spec)}")
                    case :mnesia.select(table, match_spec) do
                      results ->
                        Logger.debug("Query for country: #{country}, league: #{league} returned #{length(results)} matches")
                        results
                    end
                  end)
                  |> Enum.uniq_by(fn {_country, _league, _start_time, match_id, _team1, _team2, _markets} -> match_id end)

                Logger.debug("Total matches fetched: #{length(results)}")
                results
              end)
              |> case do
                {:atomic, results} -> results
                {:aborted, reason} ->
                  Logger.error("Mnesia select failed for #{table}: #{inspect(reason)}")
                  []
              end
            end
        end
      catch
        :exit, reason ->
          Logger.error("Mnesia table_info failed for #{table}: #{inspect(reason)}")
          []
      end

    if matches == [] and leagues != [] do
      Logger.warning("No matches found for specified country-league pairs: #{inspect(leagues)}")
    end

    # Group by country, league, and start_time
    Enum.group_by(matches, fn {country, league, start_time, _match_id, _team1, _team2, _markets} ->
      {country, league, start_time}
    end, fn {country, league, start_time, match_id, team1, team2, markets} ->
      %{
        match_id: match_id,
        start_time: start_time,
        team1_name: team1,
        team2_name: team2,
        markets: markets,
        ht: %{score: Map.get(markets, :ht_score, "")} # Add ht score for Asian Handicap display
      }
    end)
    |> Enum.map(fn {{country, league, start_time}, matches} ->
      {country, league, start_time, matches}
    end)
    |> Enum.sort_by(fn {country, _league, start_time, _matches} -> {country, start_time} end)
    |> Enum.group_by(fn {country, _league, _start_time, _matches} -> country end)
    |> Enum.map(fn {country, groups} ->
      {country,
       Enum.group_by(groups, fn {_c, league, _st, _m} -> league end, fn {_c, _l, start_time, matches} ->
         {start_time, Enum.sort_by(matches, & &1.match_id)}
       end)
       |> Enum.map(fn {league, time_groups} ->
         {league, Enum.sort_by(time_groups, fn {start_time, _m} -> start_time end)}
       end)
       |> Enum.sort_by(fn {league, _tg} -> league end)}
    end)
    |> Enum.sort_by(fn {country, _lg} -> country end)
  end

  defp format_datetime(timestamp) when is_integer(timestamp) do
    case DateTime.from_unix(timestamp) do
      {:ok, datetime} ->
        Timex.format!(datetime, "{D}.{M}.{YYYY} {h24}:{m}")
      {:error, _} ->
        "Unknown"
    end
  end

  defp format_datetime(_), do: "Unknown"

  defp get_home_away_odds(markets) do
    case markets[:home_away] do
      nil -> {nil, nil}
      odds ->
        home = Enum.find(odds, fn o -> o.name == "Home" end)
        away = Enum.find(odds, fn o -> o.name == "Away" end)
        {home && home.value, away && away.value}
    end
  end
end
