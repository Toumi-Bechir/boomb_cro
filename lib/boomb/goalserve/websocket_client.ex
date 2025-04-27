defmodule Boomb.Goalserve.WebsocketClient do
  @moduledoc """
  A GenServer that manages the WebSocket connection to Goalserve Inplay API using WebSockex.
  Handles token fetching, WebSocket connection, and data processing with reconnection logic.
  """

  use GenServer
  require Logger

  @base_url "ws://85.217.222.218:8765/ws/"
  @token_url "http://85.217.222.218:8765/api/v1/auth/gettoken"
  @sports ["soccer", "basket", "tennis", "baseball", "amfootball", "hockey", "volleyball"]
  @token_refresh_interval 60 * 60 * 1000 # 60 minutes in milliseconds
  @max_retries 5
  @retry_delay 1000 # 1 second delay between retries
  @reconnect_delay 5000 # 5 seconds delay for reconnection

  def start_link(_opts) do
    Logger.info("Starting Goalserve WebsocketClient...")
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    Logger.info("Initializing WebsocketClient, scheduling token fetch...")
    # Initialize ETS table for match cache if it doesn't exist
    unless :ets.info(:match_cache) != :undefined do
      Logger.info("Creating :match_cache ETS table")
      :ets.new(:match_cache, [:set, :public, :named_table, read_concurrency: true, write_concurrency: true])
    end
    # Initialize ETS table for heatmap data
    unless :ets.info(:heatmap_data) != :undefined do
      Logger.info("Creating :heatmap_data ETS table")
      :ets.new(:heatmap_data, [:set, :public, :named_table])
    end
    # Send immediate token fetch message
    send(self(), :fetch_token)
    {:ok, state}
  end

  @impl true
  def handle_info(:fetch_token, state) do
    Logger.info("Fetching Goalserve token...")
    case {:ok, "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1biI6InRiZWNoaXIiLCJuYmYiOjE3NDU2NTU5NzcsImV4cCI6MTc0NTY1OTU3NywiaWF0IjoxNzQ1NjU1OTc3fQ.C906Irr5Qe0Cth3TAy3RfMGMke1JyOR6TbqXI-Pzn2o"}do#fetch_token_with_retry(0) do
      {:ok, token} ->
        Logger.info("Token fetched successfully: #{token}")
        # Disconnect existing WebSocket connections
        disconnect_all(state)
        # Start WebSocket connections for each sport
        new_state =
          Enum.reduce(@sports, %{}, fn sport, acc ->
            case start_websocket(sport, token) do
              {:ok, ws_pid} ->
                Logger.info("Started WebSocket client for #{sport}")
                Map.put(acc, sport, ws_pid)
              {:error, reason} ->
                Logger.error("Failed to start WebSocket client for #{sport}: #{inspect(reason)}")
                acc
            end
          end)
        schedule_token_fetch()
        {:noreply, Map.put(new_state, :token, token)}

      {:error, reason} ->
        Logger.error("Failed to fetch Goalserve token after #{@max_retries} retries: #{inspect(reason)}")
        Process.send_after(self(), :fetch_token, 5 * 60 * 1000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:reconnect, sport}, state) do
    Logger.info("Attempting to reconnect WebSocket for #{sport}")
    case Map.get(state, :token) do
      nil ->
        Logger.error("No token available for reconnection, scheduling token fetch")
        send(self(), :fetch_token)
        {:noreply, state}
      token ->
        case start_websocket(sport, token) do
          {:ok, ws_pid} ->
            Logger.info("Successfully reconnected WebSocket for #{sport}")
            {:noreply, Map.put(state, sport, ws_pid)}
          {:error, reason} ->
            Logger.error("Failed to reconnect WebSocket for #{sport}: #{inspect(reason)}")
            # Schedule another reconnection attempt
            Process.send_after(self(), {:reconnect, sport}, @reconnect_delay)
            {:noreply, state}
        end
    end
  end

  defp fetch_token_with_retry(attempt) when attempt >= @max_retries do
    {:error, :max_retries_exceeded}
  end

  defp fetch_token_with_retry(attempt) do
    api_key = Application.get_env(:boomb, :goalserve_api_key)
    headers = [{"Content-Type", "application/json"}]
    body = Jason.encode!(%{"apiKey" => api_key})

    Logger.debug("Attempting to fetch token from #{@token_url} (attempt #{attempt + 1}/#{@max_retries})")
    case :httpc.request(:post, {String.to_charlist(@token_url), headers, 'application/json', body}, [], []) do
      {:ok, {{_, 200, _}, _headers, response_body}} ->
        response = to_string(response_body)
        case Jason.decode(response) do
          {:ok, %{"token" => token}} ->
            Logger.info("Successfully fetched token: #{token}")
            {:ok, token}
          {:error, decode_reason} ->
            Logger.warn("Failed to decode token response, retrying (attempt #{attempt + 1}/#{@max_retries}): #{inspect(decode_reason)}")
            :timer.sleep(@retry_delay)
            fetch_token_with_retry(attempt + 1)
          other ->
            Logger.warn("Invalid token response: #{inspect(other)}, retrying (attempt #{attempt + 1}/#{@max_retries})")
            :timer.sleep(@retry_delay)
            fetch_token_with_retry(attempt + 1)
        end
      {:ok, {{_, status_code, _}, _headers, response_body}} ->
        Logger.warn("Received error status code #{status_code}, retrying (attempt #{attempt + 1}/#{@max_retries}): #{inspect(response_body)}")
        :timer.sleep(@retry_delay)
        fetch_token_with_retry(attempt + 1)
      {:error, reason} ->
        Logger.warn("Failed to fetch token, retrying (attempt #{attempt + 1}/#{@max_retries}): #{inspect(reason)}")
        :timer.sleep(@retry_delay)
        fetch_token_with_retry(attempt + 1)
    end
  end

  defp start_websocket(sport, token) do
    url = "#{@base_url}#{sport}?tkn=#{token}"
    Logger.debug("Starting WebSocket connection to #{url}")
    WebSockex.start_link(
      url,
      __MODULE__.WebsocketHandler,
      %{sport: sport, parent: self()},
      name: {:via, Registry, {Boomb.Registry, sport}}
    )
  end

  defp disconnect_all(state) do
    Enum.each(state, fn {sport, _pid} when is_binary(sport) ->
      case Registry.lookup(Boomb.Registry, sport) do
        [{pid, _}] ->
          Logger.info("Disconnecting WebSocket for #{sport}")
          Process.exit(pid, :normal)
        _ ->
          Logger.debug("No WebSocket process found for #{sport} to disconnect")
      end
      # Skip token key and other non-sport keys
      {_key, _value} -> :ok
    end)
  end

  defp schedule_token_fetch do
    Logger.debug("Scheduling token fetch in #{@token_refresh_interval}ms")
    Process.send_after(self(), :fetch_token, @token_refresh_interval)
  end

  defmodule WebsocketHandler do
    use WebSockex
    require Logger

    @ping_interval 30_000 # 30 seconds

    def handle_connect(_conn, state) do
      Logger.info("Connected to Goalserve WebSocket for #{state.sport}")
      # Schedule periodic ping to keep connection alive
      schedule_ping()
      {:ok, state}
    end

    def handle_frame({:text, msg}, state) do
      Logger.debug("Received WebSocket message for #{state.sport}: #{String.slice(msg, 0, 100)}...")
      try do
        case Jason.decode(msg) do
          {:ok, %{"mt" => "avl"} = data} ->
            handle_avl_message(data)
            {:ok, state}
          {:ok, %{"mt" => "updt"} = data} ->
            handle_updt_message(data)
            {:ok, state}
          {:ok, %{"mt" => "ping"}} ->
            # Respond to ping with pong
            {:reply, {:text, Jason.encode!(%{"mt" => "pong"})}, state}
          {:ok, other} ->
            Logger.debug("Received other message type: #{inspect(other)}")
            {:ok, state}
          {:error, reason} ->
            Logger.error("Failed to decode message for #{state.sport}: #{inspect(reason)}")
            {:ok, state}
        end
      rescue
        e ->
          Logger.error("Error processing message for #{state.sport}: #{inspect(e)}\nMessage: #{inspect(msg)}")
          {:ok, state}
      end
    end

    def handle_frame({:ping, msg}, state) do
      Logger.debug("Received ping for #{state.sport}")
      {:reply, {:pong, msg}, state}
    end

    def handle_frame({:pong, _msg}, state) do
      Logger.debug("Received pong for #{state.sport}")
      {:ok, state}
    end

    def handle_disconnect(%{reason: reason}, state) do
      Logger.warn("Disconnected from Goalserve WebSocket for #{state.sport}: #{inspect(reason)}")
      # Notify parent process to reconnect
      if Map.has_key?(state, :parent) do
        Process.send(state.parent, {:reconnect, state.sport}, [])
      end
      # Don't attempt reconnect here, let parent handle it
      {:ok, state}
    end

    def handle_info(:send_ping, state) do
      Logger.debug("Sending ping to keep connection alive for #{state.sport}")
      schedule_ping()
      {:reply, {:ping, ""}, state}
    end

    def handle_info(msg, state) do
      Logger.warn("Received unexpected message in WebSocket for #{state.sport}: #{inspect(msg)}")
      {:ok, state}
    end

    defp schedule_ping do
      Process.send_after(self(), :send_ping, @ping_interval)
    end

    defp handle_avl_message(data) do
      sport = data["sp"]
      events = case data["evts"] do
        nil ->
          Logger.warn("No events in avl message for #{sport}")
          []
        events when is_list(events) ->
          Enum.map(events, fn event ->
            %{
              id: event["id"],
              sport: sport,
              competition: event["cmp_name"],
              team1: get_in(event, ["t1", "n"]),
              team2: get_in(event, ["t2", "n"]),
              score: nil,
              time: nil,
              stats: nil,
              odds: nil,
              status: "upcoming",
              events: []
            }
          end)
        other ->
          Logger.error("Unexpected evts format in avl message: #{inspect(other)}")
          []
      end

      Enum.each(events, fn match ->
        try do
          Boomb.Storage.MnesiaSetup.write(match)
          :ets.insert(:match_cache, {match.id, match})
          Logger.info("Broadcasting new match: #{match.id}")
          Phoenix.PubSub.broadcast(Boomb.PubSub, "matches", {:new_match, match})
        rescue
          e -> Logger.error("Error processing match data: #{inspect(e)}")
        end
      end)
    end

    defp handle_updt_message(data) do
      match_id = data["id"]
      sport = data["sp"]

      # Safety checks for nil values
      case match_id do
        nil ->
          Logger.warn("Missing match ID in update message: #{inspect(data)}")
          :ok
        _ ->
          cms = data["cms"] || []
          score = parse_score(cms)
          time = data["et"]
          stats = parse_stats(data)
          odds = data["odds"]
          events = parse_events(cms)
          heatmap_data = []#update_heatmap(data["xy"], match_id)
          status = if data["pc"] == 1, do: "live", else: "finished"

          case :ets.lookup(:match_cache, match_id) do
            [{_id, match}] ->
              updated_match = %{
                match
                | score: score,
                  time: time,
                  stats: stats,
                  odds: odds,
                  events: events,
                  heatmap: heatmap_data,
                  status: status
              }

              try do
                Boomb.Storage.MnesiaSetup.write(updated_match)
                :ets.insert(:match_cache, {match_id, updated_match})
                Logger.info("Broadcasting match update: #{match_id}")
                Phoenix.PubSub.broadcast(Boomb.PubSub, "match:#{match_id}", {:update_match, updated_match})
              rescue
                e -> Logger.error("Error updating match data: #{inspect(e)}")
              end

            [] ->
              # Handle match not in cache (could be created on the fly)
              Logger.debug("Match not found in cache: #{match_id}, fetching data from Goalserve")
              # Implementation for fetching match details could be added here
              :ok
          end
      end
    end

    defp parse_score(nil), do: "0 - 0"
    defp parse_score([]), do: "0 - 0"
    defp parse_score(cms) do
      try do
        goals = Enum.filter(cms, fn %{"mt" => mt} -> mt == "255" end)
        home_team = case cms do
          [%{"t1" => t1} | _] when not is_nil(t1) -> t1
          _ -> "Home"
        end
        away_team = case cms do
          [%{"t2" => t2} | _] when not is_nil(t2) -> t2
          _ -> "Away"
        end

        home_goals = Enum.count(goals, fn goal ->
          case goal do
            %{"n" => n} when is_binary(n) ->
              String.contains?(n, "(#{home_team})")
            _ -> false
          end
        end)

        away_goals = Enum.count(goals, fn goal ->
          case goal do
            %{"n" => n} when is_binary(n) ->
              String.contains?(n, "(#{away_team})")
            _ -> false
          end
        end)

        "#{home_goals} - #{away_goals}"
      rescue
        e ->
          Logger.error("Error parsing score: #{inspect(e)}")
          "0 - 0"
      end
    end

    defp parse_stats(data) do
      %{
        "attacks" => data["a"] || [0, 0],
        "possession" => parse_possession(data["Possession %"]),
        "shots_on_target" => data["h1"] || [0, 0],
        "corners" => data["c"] || [0, 0],
        "yellow_cards" => data["y"] || [0, 0],
        "red_cards" => data["r"] || [0, 0],
        "ball_position" => parse_ball_position(data["xy"])
      }
    end

    defp parse_possession(nil), do: [50, 50]
    defp parse_possession(possession) when not is_binary(possession), do: [50, 50]
    defp parse_possession(possession) do
      try do
        case String.split(possession, ":") do
          [home, away] ->
            [
              String.trim(home) |> String.to_integer(),
              String.trim(away) |> String.to_integer()
            ]
          _ -> [50, 50]
        end
      rescue
        _ -> [50, 50]
      end
    end

    defp parse_ball_position(nil), do: nil
    defp parse_ball_position(xy) when not is_binary(xy), do: nil
    defp parse_ball_position(xy) do
      try do
        [x_str, y_str] = String.split(xy, ",")
        x = String.trim(x_str) |> String.to_integer()
        y = String.trim(y_str) |> String.to_integer()
        %{x: x, y: y}
      rescue
        _ -> nil
      end
    end

    defp parse_events(nil), do: []
    defp parse_events([]), do: []
    defp parse_events(cms) do
      try do
        Enum.map(cms, fn event ->
          %{
            id: event["id"] || "event_#{:erlang.system_time(:millisecond)}",
            type: event["mt"],
            time: event["tm"],
            description: event["n"],
            period: event["p"],
            shot: if(event["mt"] == "255" || (is_binary(event["n"]) && event["n"] =~ ~r/Shot/), do: simulate_shot(event), else: nil)
          }
        end)
        |> Enum.reject(fn event -> is_nil(event.id) end)
        |> Enum.sort_by(& &1.time)
      rescue
        e ->
          Logger.error("Error parsing events: #{inspect(e)}")
          []
      end
    end

    defp simulate_shot(event) do
      try do
        team = case event do
          %{"n" => n} when is_binary(n) ->
            if String.contains?(n, "(#{List.first(String.split(n, " - "))})")
              do "home"
              else "away"
            end
          _ -> Enum.random(["home", "away"])
        end

        x = if team == "home", do: Enum.random(70..95), else: Enum.random(5..30)
        y = Enum.random(15..45)
        outcome = case event["mt"] do
          "255" -> "goal"
          _ -> if(Enum.random(0..1) == 1, do: "on_target", else: "off_target")
        end

        %{
          x: x,
          y: y,
          outcome: outcome,
          team: team
        }
      rescue
        _ ->
          %{
            x: Enum.random(5..95),
            y: Enum.random(5..45),
            outcome: "off_target",
            team: "unknown"
          }
      end
    end

    #defp update_heatmap(nil, _match_id), do: initialize_heatmap()
    #defp update_heatmap(xy, match_id) when not is_binary(xy), do: initialize_heatmap()
    defp update_heatmap(xy, match_id) do



""

    end
  end

  def simulate_matches(count \\ 1500) do
    Enum.each(1..count, fn i ->
      sport = Enum.random(@sports)
      match = %{
        id: "sim_#{i}",
        sport: sport,
        competition: "Simulated League",
        team1: "Team A #{i}",
        team2: "Team B #{i}",
        score: nil,
        time: nil,
        stats: nil,
        odds: nil,
        status: "upcoming",
        events: []
      }

      Boomb.Storage.MnesiaSetup.write(match)
      :ets.insert(:match_cache, {match.id, match})
      Logger.info("Broadcasting new match: #{match.id}")
      Phoenix.PubSub.broadcast(Boomb.PubSub, "matches", {:new_match, match})

      Process.sleep(100)
      updated_match = %{
        match
        | score: "1 - 0",
          time: 300,
          stats: %{
            "attacks" => [10, 8],
            "possession" => [55, 45],
            "shots_on_target" => [2, 1],
            "corners" => [3, 2],
            "yellow_cards" => [1, 0],
            "red_cards" => [0, 0],
            "ball_position" => %{x: 50, y: 30}
          },
          odds: [
            %{"id" => 50246, "o" => [%{"n" => "1", "v" => 1.5, "b" => 0}, %{"n" => "X", "v" => 3.0, "b" => 0}, %{"n" => "2", "v" => 2.5, "b" => 0}]},
            %{"id" => 10115, "o" => [%{"n" => "1X", "v" => 1.3, "b" => 0}, %{"n" => "X2", "v" => 1.4, "b" => 0}, %{"n" => "12", "v" => 1.2, "b" => 0}]}
          ],
          events: [
            %{id: "sim_event_#{i}", type: "255", time: 120, description: "Goal scored by Team A #{i}", period: 1, shot: %{x: 90, y: 30, outcome: "goal", team: "home"}}
          ],
          heatmap: initialize_heatmap(),
          status: "live"
      }

      Boomb.Storage.MnesiaSetup.write(updated_match)
      :ets.insert(:match_cache, {match.id, updated_match})
      Logger.info("Broadcasting match update: #{match.id}")
      Phoenix.PubSub.broadcast(Boomb.PubSub, "match:#{match.id}", {:update_match, updated_match})
    end)
  end

  def initialize_heatmap do
    for x <- 0..9, y <- 0..5, into: %{}, do: {{x, y}, 0}
  end
end
