defmodule Boomb.GoalserveWebsocket do
  use WebSockex
  require Logger

  @base_url "ws://85.217.222.218:8765/ws/"
  @max_retries 5
  @retry_delay 1000  # 1 second delay between retries

  def start_link(sport_type) do
    #case get_token_with_retry(0) do
    #  {:ok, token} ->
    #    url = "#{@base_url}#{sport_type}?tkn=#{token}"
    #    case WebSockex.start_link(url, __MODULE__, %{sport_type: sport_type}, name: {:via, Registry, {Boomb.Registry, sport_type}}) do
    #      {:ok, pid} ->
    #        Logger.info("WebSocket client for #{sport_type} started successfully")
    #        {:ok, pid}
    #      {:error, reason} ->
    #        Logger.error("Failed to start WebSocket client for #{sport_type}: #{inspect(reason)}")
    #        {:error, reason}
    #    end
    #  {:error, reason} ->
    #    Logger.error("Failed to start WebSocket for #{sport_type} after #{@max_retries} retries: #{inspect(reason)}")
    #    {:error, reason}
    #end
    url = "#{@base_url}#{sport_type}?tkn=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1biI6InRiZWNoaXIiLCJuYmYiOjE3NDQzMTczOTQsImV4cCI6MTc0NDMyMDk5NCwiaWF0IjoxNzQ0MzE3Mzk0fQ.-i_Me5zEJKqBzsvaM4Of4gMy8KwHAGGsq6EN4ItfSC0"#{token}
    WebSockex.start_link(url, __MODULE__, %{sport_type: sport_type}, name: {:via, Registry, {Boomb.Registry, sport_type}})
  end



  def handle_connect(_conn, state) do
    Logger.info("Connected to Goalserve WebSocket for #{state.sport_type}")
    {:ok, state}
  end

  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, %{"mt" => "avl"} = data} ->
        #Logger.debug("Received avl message for #{state.sport_type}: #{inspect(data)}")
        handle_avl_message(data)
        {:ok, state}
      {:ok, %{"mt" => "updt"} = data} ->
        #Logger.debug("Received updt message for #{state.sport_type}: #{inspect(data)}")
        handle_updt_message(data)
        {:ok, state}
      {:error, reason} ->
        Logger.error("Failed to decode message for #{state.sport_type}: #{inspect(reason)}")
        {:ok, state}
    end
  end

  def handle_disconnect(_disconnect_map, state) do
    Logger.info("Disconnected from Goalserve WebSocket for #{state.sport_type}, attempting reconnect")
    {:reconnect, state}
  end

  def handle_info(msg, state) do
    Logger.warn("Received unexpected message in WebSocket for #{state.sport_type}: #{inspect(msg)}")
    {:ok, state}
  end

  defp handle_avl_message(data) do
    sport = data["sp"]
    # Extract event IDs from the "avl" message
    available_event_ids = Enum.map(data["evts"], fn event -> event["id"] end)
    Logger.info("Processing avl message for #{sport} with #{length(available_event_ids)} events")

    # Get existing events for this sport from Mnesia
    existing_events = Boomb.Event.list_by_sport(sport)
    existing_event_ids = Enum.map(existing_events, fn event -> event.event_id end)

    # Delete events that are no longer available
    events_to_delete = existing_event_ids -- available_event_ids
    Enum.each(events_to_delete, fn event_id ->
      case Boomb.Event.delete(event_id) do
        {:atomic, :ok} ->
          Logger.info("Deleted event #{event_id} for #{sport} as it is no longer available")
          # Also remove from OddsCache
          :ets.delete(:odds_cache, event_id)
        {:aborted, reason} ->
          Logger.error("Failed to delete event #{event_id} for #{sport}: #{inspect(reason)}")
      end
    end)

    # Upsert the available events
    events = Enum.map(data["evts"], fn event ->
      %{
        event_id: event["id"],
        sport: sport,
        mid: event["mid"],
        competition_id: event["cmp_id"],
        competition_name: event["cmp_name"],
        team1: event["t1"]["n"],
        team2: event["t2"]["n"],
        provider_id: event["fi"],
        period_code: event["pc"]
      }
    end)
    Enum.each(events, fn event ->
      case Boomb.Event.upsert(event) do
        {:atomic, :ok} ->
          :ok
        {:aborted, reason} ->
          Logger.error("Failed to upsert event #{event.event_id} for #{sport}: #{inspect(reason)}")
      end
    end)

    # Update SportsCache and broadcast the change
    sports = Boomb.Event.group_by_sport()
    Logger.info("Updated sports cache for #{sport} with #{length(Map.get(sports, sport, []))} events")
    Phoenix.PubSub.broadcast(Boomb.PubSub, "events_available:#{sport}", %{events: events})
    Boomb.SportsCache.update_sports(sports)
  end

  defp handle_updt_message(data) do
    event_id = data["id"]
    sport = data["sp"]
    # Create a minimal event record with as much data as possible from the "updt" message
    minimal_event = %{
      event_id: event_id,
      sport: sport,
      mid: data["mid"],
      competition_id: data["cmp_id"],
      competition_name: data["cmp_name"],
      team1: get_in(data, ["t1", "n"]),
      team2: get_in(data, ["t2", "n"]),
      period_code: data["pc"]
    }
    case Boomb.Event.upsert(minimal_event) do
      {:atomic, :ok} ->
        :ok
      {:aborted, reason} ->
        Logger.error("Failed to upsert minimal event #{event_id} for #{sport}: #{inspect(reason)}")
    end

    odds = normalize_odds(data["odds"])
    odds_data = %{
      odds: odds,
      sport: sport,
      stats: data["stats"],
      comments: data["cms"],
      period_time: parse_time(sport, data),
      score: parse_score(sport, data),
      state: data["sc"],           # Add state code
      ball_position: data["xy"]
    }
    Boomb.OddsCache.update_odds(event_id, odds_data)
    Boomb.OddsThrottler.update_odds(event_id, %{
      event_id: event_id,
      sport: sport,
      odds: odds,
      stats: data["stats"],
      comments: data["cms"],
      period_time: parse_time(sport, data),
      score: parse_score(sport, data),
      state: data["sc"],           # Add state code
      ball_position: data["xy"]
    })
  end

  defp normalize_odds(odds_list) do
    Enum.reduce(odds_list, %{}, fn odds, acc ->
      market_id = odds["id"]
      market_odds = Enum.map(odds["o"], fn o ->
        %{
          name: o["n"],
          value: o["v"],
          last_value: o["lv"],
          blocked: o["b"] == 1
        }
      end)
      Map.put(acc, market_id, %{odds: market_odds, handicap: odds["ha"], blocked: odds["bl"] == 1})
    end)
  end

  defp parse_score("soccer", data) do
    case get_in(data, ["stats", "a"]) do
      [team1_goals, team2_goals] -> "#{team1_goals}:#{team2_goals}"
      _ -> "0:0"
    end
  end

  defp parse_score("tennis", data) do
    get_in(data, ["stats", "POINTS"]) || "0-0"
  end

  defp parse_score(sport, data) when sport in ["basket", "hockey", "volleyball", "baseball"] do
    case get_in(data, ["stats", "T"]) do
      [team1_score, team2_score] -> "#{team1_score}:#{team2_score}"
      _ -> "0:0"
    end
  end

  defp parse_score(_sport, _data), do: "0:0"

  defp parse_time(sport, data) when sport in ["soccer", "hockey", "volleyball"] do
    case data["et"] do
      seconds when is_integer(seconds) -> seconds
      _ -> 0
    end
  end

  defp parse_time(_sport, _data), do: nil

  defp get_token_with_retry(attempt) when attempt >= @max_retries do
    {:error, :max_retries_exceeded}
  end

  defp get_token_with_retry(attempt) do
    case GenServer.whereis(Boomb.GoalserveToken) do
      nil ->
        Logger.warn("Boomb.GoalserveToken not found, retrying (attempt #{attempt + 1}/#{@max_retries})")
        :timer.sleep(@retry_delay)
        get_token_with_retry(attempt + 1)
      _pid ->
        case Boomb.GoalserveToken.get_token() do
          nil ->
            Logger.warn("Failed to get token, retrying (attempt #{attempt + 1}/#{@max_retries})")
            :timer.sleep(@retry_delay)
            get_token_with_retry(attempt + 1)
          token ->
            {:ok, token}
        end
    end
  end
end