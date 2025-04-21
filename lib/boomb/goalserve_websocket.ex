defmodule Boomb.GoalserveWebsocket do
  use WebSockex
  require Logger

  @base_url "ws://85.217.222.218:8765/ws/"
  @max_retries 5
  @retry_delay 1000  # 1 second delay between retries
  @simulate Application.compile_env(:boomb, :simulate_websocket, false)
  @simulate_sports Application.compile_env(:boomb, :simulate_sports, ["soccer"])  # Limit to soccer by default
  @simulation_event_count 1200
  @simulation_update_interval 300  # 10 seconds

  def start_link(sport_type) do
    if @simulate and sport_type in @simulate_sports do
      Logger.info("Starting WebSocket simulation for #{sport_type}")
      {:ok, pid} = GenServer.start_link(__MODULE__, %{sport_type: sport_type}, name: {:via, Registry, {Boomb.Registry, sport_type}})
      send(pid, :simulate_avl)
      {:ok, pid}
    else
      case get_token_with_retry(0) do
        {:ok, token} ->
          url = "#{@base_url}#{sport_type}?tkn=#{token}"
          case WebSockex.start_link(url, __MODULE__, %{sport_type: sport_type}, name: {:via, Registry, {Boomb.Registry, sport_type}}) do
            {:ok, pid} ->
              Logger.info("Started WebSocket client for #{sport_type}")
              {:ok, pid}
            {:error, reason} ->
              Logger.error("Failed to start WebSocket client for #{sport_type}: #{inspect(reason)}")
              {:error, reason}
          end
        {:error, reason} ->
          Logger.error("Failed to start WebSocket for #{sport_type} after #{@max_retries} retries: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  def init(state) do
    if @simulate and state.sport_type in @simulate_sports do
      Logger.info("Initializing simulation for #{state.sport_type}")
      :timer.send_interval(@simulation_update_interval, :simulate_updt)
      {:ok, state}
    else
      {:ok, state}
    end
  end

  def handle_connect(_conn, state) do
    Logger.info("Connected to Goalserve WebSocket for #{state.sport_type}")
    {:ok, state}
  end

  def handle_frame({:text, msg}, state) do
    if @simulate and state.sport_type in @simulate_sports do
      Logger.debug("Ignoring real WebSocket frame in simulation mode for #{state.sport_type}")
      {:ok, state}
    else
      case Jason.decode(msg) do
        {:ok, %{"mt" => "avl"} = data} ->
          handle_avl_message(data)
          {:ok, state}
        {:ok, %{"mt" => "updt"} = data} ->
          handle_updt_message(data)
          {:ok, state}
        {:error, reason} ->
          Logger.error("Failed to decode message for #{state.sport_type}: #{inspect(reason)}")
          {:ok, state}
      end
    end
  end

  def handle_disconnect(_disconnect_map, state) do
    if @simulate and state.sport_type in @simulate_sports do
      Logger.info("Simulation mode: Ignoring WebSocket disconnect for #{state.sport_type}")
      {:ok, state}
    else
      Logger.info("Disconnected from Goalserve WebSocket for #{state.sport_type}, attempting reconnect")
      {:reconnect, state}
    end
  end

  def handle_info(:simulate_avl, state) do
    Logger.info("Simulating avl message for #{state.sport_type} with #{@simulation_event_count} events")
    data = generate_mock_avl_data(state.sport_type)
    handle_avl_message(data)
    {:noreply, state}  # Fixed return value
  end

  def handle_info(:simulate_updt, state) do
    Logger.debug("Simulating updt message for #{state.sport_type}")
    events = Boomb.Event.list_by_sport(state.sport_type)
    Logger.debug("Found #{length(events)} events for #{state.sport_type} in Mnesia")
    Enum.each(events, fn event ->
      data = generate_mock_updt_data(state.sport_type, event.event_id)
      handle_updt_message(data)
    end)
    {:noreply, state}  # Fixed return value
  end

  def handle_info(msg, state) do
    Logger.warn("Received unexpected message in WebSocket for #{state.sport_type}: #{inspect(msg)}")
    {:noreply, state}
  end

  defp handle_avl_message(data) do
    sport = data["sp"]
    available_event_ids = Enum.map(data["evts"], fn event -> event["id"] end)
    #Logger.info("Processing avl message for #{sport} with #{length(available_event_ids)} events")

    existing_events = Boomb.Event.list_by_sport(sport)
    existing_event_ids = Enum.map(existing_events, fn event -> event.event_id end)
    #Logger.debug("Existing event IDs for #{sport}: #{length(existing_event_ids)}")

    events_to_delete = existing_event_ids -- available_event_ids
    Enum.each(events_to_delete, fn event_id ->
      case Boomb.Event.delete(event_id) do
        {:atomic, :ok} ->
          Logger.info("Deleted event #{event_id} for #{sport} as it is no longer available")
          :ets.delete(:odds_cache, event_id)
        {:aborted, reason} ->
          Logger.error("Failed to delete event #{event_id} for #{sport}: #{inspect(reason)}")
      end
    end)

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
    #Logger.debug("Upserting #{length(events)} events for #{sport}")
    Enum.each(events, fn event ->
      case Boomb.Event.upsert(event) do
        {:atomic, :ok} ->
          ""
          #Logger.debug("Upserted event #{event.event_id} for #{sport}")
        {:aborted, reason} ->
          Logger.error("Failed to upsert event #{event.event_id} for #{sport}: #{inspect(reason)}")
      end
    end)

    sports = Boomb.Event.group_by_sport()
    event_count = length(Map.get(sports, sport, []))
    #Logger.info("Updated sports cache for #{sport} with #{event_count} events")
    if sport == "soccer" and event_count != @simulation_event_count do
      Logger.error("Expected #{@simulation_event_count} soccer events, but got #{event_count}")
      #Logger.debug("Sports data: #{inspect(sports, limit: 10)}")
    end
    Phoenix.PubSub.broadcast(Boomb.PubSub, "events_available:#{sport}", %{events: events})
    Boomb.SportsCache.update_sports(sports)
  end

  defp handle_updt_message(data) do
    event_id = data["id"]
    sport = data["sp"]
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
        ""
        #Logger.debug("Upserted minimal event #{event_id} for #{sport}")
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
      state: data["sc"],
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
      state: data["sc"],
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

  # Simulation helper functions

  defp generate_mock_avl_data(sport) do
    competitions = [
      {"Premier League", "PL001"},
      {"La Liga", "LL002"},
      {"Serie A", "SA003"},
      {"Bundesliga", "BL004"},
      {"Ligue 1", "L1005"}
    ]

    teams = [
      {"Manchester United", "ManUtd"},
      {"Liverpool", "LFC"},
      {"Real Madrid", "RMA"},
      {"Barcelona", "BAR"},
      {"Juventus", "JUV"},
      {"Bayern Munich", "BAY"},
      {"Paris Saint-Germain", "PSG"},
      {"Chelsea", "CHE"},
      {"Arsenal", "ARS"},
      {"Inter Milan", "INT"}
    ]

    events = Enum.map(1..@simulation_event_count, fn i ->
      {comp_name, comp_id} = Enum.random(competitions)
      {team1_name, team1_id} = Enum.random(teams)
      {team2_name, team2_id} = Enum.random(teams -- [{team1_name, team1_id}])
      %{
        "id" => "EVT#{sport}#{i}",  # Unique per sport
        "mid" => "MID#{sport}#{i}",
        "cmp_id" => comp_id,
        "cmp_name" => comp_name,
        "t1" => %{"n" => team1_name, "id" => team1_id},
        "t2" => %{"n" => team2_name, "id" => team2_id},
        "fi" => "FIX#{sport}#{i}",
        "pc" => Enum.random([0, 1, 2])  # 0: Not started, 1: 1st Half, 2: 2nd Half
      }
    end)

    %{
      "mt" => "avl",
      "sp" => sport,
      "evts" => events
    }
  end

  defp generate_mock_updt_data(sport, event_id) do
    {comp_name, comp_id} = Enum.random([
      {"Premier League", "PL001"},
      {"La Liga", "LL002"},
      {"Serie A", "SA003"},
      {"Bundesliga", "BL004"},
      {"Ligue 1", "L1005"}
    ])

    teams = Enum.random([
      {"Manchester United", "ManUtd"},
      {"Liverpool", "LFC"},
      {"Real Madrid", "RMA"},
      {"Barcelona", "BAR"},
      {"Juventus", "JUV"}
    ])

    odds = [
      %{
        "id" => "1777",
        "ha" => nil,
        "bl" => 0,
        "o" => [
          %{"n" => "1", "v" => Float.round(1.5 + :rand.uniform(), 2), "lv" => 1.5, "b" => 0},
          %{"n" => "X", "v" => Float.round(3.0 + :rand.uniform(), 2), "lv" => 3.0, "b" => 0},
          %{"n" => "2", "v" => Float.round(4.5 + :rand.uniform(), 2), "lv" => 4.5, "b" => 0}
        ]
      },
      %{
        "id" => "27",
        "ha" => nil,
        "bl" => 0,
        "o" => [
          %{"n" => "1", "v" => Float.round(2.0 + :rand.uniform(), 2), "lv" => 2.0, "b" => 0},
          %{"n" => "X", "v" => Float.round(2.5 + :rand.uniform(), 2), "lv" => 2.5, "b" => 0},
          %{"n" => "2", "v" => Float.round(3.0 + :rand.uniform(), 2), "lv" => 3.0, "b" => 0}
        ]
      },
      %{
        "id" => "1016",
        "ha" => nil,
        "bl" => 0,
        "o" => [
          %{"n" => "1", "v" => Float.round(2.2 + :rand.uniform(), 2), "lv" => 2.2, "b" => 0},
          %{"n" => "No goal", "v" => Float.round(8.0 + :rand.uniform(), 2), "lv" => 8.0, "b" => 0},
          %{"n" => "2", "v" => Float.round(2.3 + :rand.uniform(), 2), "lv" => 2.3, "b" => 0}
        ]
      },
      %{
        "id" => "31",
        "ha" => "2.5",
        "bl" => 0,
        "o" => [
          %{"n" => "Over", "v" => Float.round(1.8 + :rand.uniform(), 2), "lv" => 1.8, "b" => 0},
          %{"n" => "Under", "v" => Float.round(1.9 + :rand.uniform(), 2), "lv" => 1.9, "b" => 0}
        ]
      }
    ]

    %{
      "mt" => "updt",
      "id" => event_id,
      "sp" => sport,
      "mid" => "MID#{event_id}",
      "cmp_id" => comp_id,
      "cmp_name" => comp_name,
      "t1" => %{"n" => elem(teams, 0), "id" => elem(teams, 1)},
      "t2" => %{"n" => Enum.random(["Chelsea", "Arsenal"]), "id" => "CHE"},
      "pc" => Enum.random([0, 1, 2]),
      "odds" => odds,
      "stats" => %{
        "a" => [Enum.random(0..3), Enum.random(0..3)]  # Random score like [2, 1]
      },
      "cms" => [],
      "et" => Enum.random(0..2700),  # Up to 45 minutes in seconds
      "sc" => Enum.random(["LIVE", "HALFTIME"]),
      "xy" => nil
    }
  end
end
