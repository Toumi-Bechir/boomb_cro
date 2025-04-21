defmodule Boomb.Pregame.PregameFetcher do
  use GenServer
  require Logger

  @sports [
    :soccer, :basketball, :tennis, :hockey, :handball, :volleyball, :football,
    :baseball, :cricket, :rugby, :rugbyleague, :boxing, :esports, :futsal,
    :mma, :table_tennis, :golf, :darts
  ]
  @base_url "http://www.goalserve.com/getfeed/d306a694785d45065cb608dada5f9a88/getodds"
  @sport_endpoints %{
    basketball: "basket_10",
    cricket: "cricket_10",
    mma: "mma_10",
    soccer: "soccer_10",
    tennis: "tennis_10",
    hockey: "hockey_10",
    handball: "handball_10",
    volleyball: "volleyball_10",
    football: "football_10",
    baseball: "baseball_10",
    rugby: "rugby_10",
    rugbyleague: "rugbyleague_10",
    boxing: "boxing_10",
    esports: "esports_10",
    futsal: "futsal_10",
    table_tennis: "tabletennis_10",
    golf: "golf_10",
    darts: "darts_10"
  }
  @initial_timeout 180_000 # 180 seconds
  @update_interval 5 * 60 * 1_000 # 5 minutes
  @force_fetch_interval 15 * 60 * 1_000 # 15 minutes
  @delete_interval 30 * 60 * 1_000 # 30 minutes
  @retry_base_delay 1_000 # 1 second initial retry delay
  @max_retries 3
  @initial_fetch_delay 5_000 # 5 seconds between initial sport fetches
  @initial_retry_delay 120_000 # 2 minutes delay for retrying failed initial fetches
  @health_check_interval 10 * 60 * 1_000 # 10 minutes for health checks
  @current_year "2025" # Assume 2025 for dates missing year

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    state = %{
      timestamps: %{},
      has_initial_fetch: Enum.into(@sports, %{}, &{&1, false})
    }
    Logger.info("PregameFetcher initializing")
    schedule_initial_fetch()
    schedule_delete_old_matches()
    schedule_health_check()
    schedule_force_fetch()
    {:ok, state}
  end

  def handle_info(:fetch, state) do
    Logger.info("Starting periodic fetch for all sports, state: #{inspect(state.has_initial_fetch, pretty: true)}")
    missing_initial = Enum.filter(@sports, fn sport -> not state.has_initial_fetch[sport] end)
    if missing_initial != [] do
      Logger.warning("Sports missing initial fetch: #{inspect(missing_initial)}")
    end

    new_state =
      Enum.reduce(@sports, state, fn sport, acc ->
        if acc.has_initial_fetch[sport] do
          fetch_with_retry(sport, Map.get(acc.timestamps, sport), 0, acc)
        else
          Logger.warning("Skipping update for #{sport} as initial fetch has not succeeded")
          acc
        end
      end)

    schedule_next_fetch()
    {:noreply, new_state}
  end

  def handle_info(:force_fetch, state) do
    Logger.info("Starting force fetch for all sports")
    new_state =
      Enum.reduce(@sports, state, fn sport, acc ->
        fetch_with_retry(sport, Map.get(acc.timestamps, sport) || nil, 0, acc)
      end)

    schedule_force_fetch()
    {:noreply, new_state}
  end

  def handle_info({:retry_fetch, sport, retry_count}, state) do
    new_state = fetch_with_retry(sport, Map.get(state.timestamps, sport), retry_count, state)
    {:noreply, new_state}
  end

  def handle_info({:retry_initial_fetch, sport}, state) do
    Logger.info("Retrying initial fetch for #{sport}")
    new_state = fetch_with_retry(sport, nil, 0, state)
    {:noreply, new_state}
  end

  def handle_info({:fetch_sport, sport}, state) do
    Logger.info("Initial call for #{sport}")
    new_state = fetch_with_retry(sport, nil, 0, state)
    {:noreply, new_state}
  end

  def handle_info(:delete_old_matches, state) do
    Logger.info("Deleting old matches")
    delete_old_matches()
    schedule_delete_old_matches()
    {:noreply, state}
  end

  def handle_info(:health_check, state) do
    Logger.info("Running health check")
    missing_initial = Enum.filter(@sports, fn sport -> not state.has_initial_fetch[sport] end)
    if missing_initial != [] do
      Logger.warning("Sports still missing initial fetch: #{inspect(missing_initial)}")
      Enum.each(missing_initial, fn sport ->
        Logger.info("Scheduling retry initial fetch for #{sport}")
        Process.send_after(self(), {:retry_initial_fetch, sport}, @initial_retry_delay)
      end)
    end
    schedule_health_check()
    {:noreply, state}
  end

  defp fetch_with_retry(sport, ts, retry_count, state) do
    is_initial = ts == nil
    case fetch_sport(sport, ts) do
      {:ok, data, new_ts} ->
        store_matches(sport, data)
        broadcast_update(sport)
        new_state = update_timestamp(state, sport, new_ts)
        if is_initial do
          Logger.info("Initial fetch succeeded for #{sport}")
          put_in(new_state.has_initial_fetch[sport], true)
        else
          new_state
        end
      {:error, :too_many_requests} when retry_count < @max_retries ->
        delay = @retry_base_delay * :math.pow(2, retry_count)
        Logger.warning("Rate limit for #{sport}, retrying in #{delay}ms (attempt #{retry_count + 1})")
        Process.send_after(self(), {:retry_fetch, sport, retry_count + 1}, round(delay))
        state
      {:error, reason} ->
        Logger.error("Failed to fetch #{sport}: #{inspect(reason)}")
        if is_initial and retry_count >= @max_retries do
          Logger.warning("Max retries reached for initial fetch of #{sport}, scheduling retry in #{@initial_retry_delay}ms")
          Process.send_after(self(), {:retry_initial_fetch, sport}, @initial_retry_delay)
        end
        state
    end
  end

  defp fetch_sport(sport, nil) do
    cat = Map.get(@sport_endpoints, sport, "#{sport}_10")
    url = "#{@base_url}/#{sport}?cat=#{cat}&bm=16&json=1"
    Logger.info("Initial call for #{sport}")
    fetch(url, @initial_timeout)
  end

  defp fetch_sport(sport, ts) do
    cat = Map.get(@sport_endpoints, sport, "#{sport}_10")
    url = "#{@base_url}/#{sport}?cat=#{cat}&bm=16&json=1&ts=#{ts}"
    Logger.info("Update call for #{sport}")
    fetch(url, 30_000)
  end

  defp fetch(url, timeout) do
    case Tesla.get(url, opts: [timeout: timeout]) do
      {:ok, %Tesla.Env{status: 200, body: body, headers: headers}} ->
        if Enum.any?(headers, fn {k, v} -> k == "content-type" and String.contains?(v, "text/html") end) do
          Logger.error("Received HTML response, likely 404: #{String.slice(body, 0, 100)}...")
          {:error, :invalid_response}
        else
          case Jason.decode(body) do
            {:ok, %{"scores" => scores}} ->
              ts = scores["ts"] || scores["timestamp"] || "0"
              categories = scores["categories"] || scores["category"] || []
              Logger.info("Fetched data: #{length(categories)} categories, ts: #{ts}")
              {:ok, categories, ts}
            {:ok, %{"message" => message, "status" => status}} ->
              Logger.error("API error, status: #{status}, message: #{message}")
              {:error, {:api_error, status, message}}
            {:error, reason} ->
              Logger.error("JSON decode failed: #{inspect(reason)}")
              {:error, {:json_decode, reason}}
          end
        end
      {:ok, %Tesla.Env{status: status, body: body}} ->
        Logger.error("Unexpected status #{status}: #{String.slice(body, 0, 100)}...")
        {:error, {:http_error, status}}
      {:error, reason} ->
        Logger.error("Tesla error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp store_matches(sport, categories) do
    table = String.to_atom("pregame_#{sport}")
    now = System.system_time(:second)

    if categories == [] do
      Logger.warning("No categories found for #{sport}")
    end

    match_count = Enum.reduce(categories, 0, fn category, acc ->
      matches = category["matches"] || []
      acc + length(matches)
    end)

    result = :mnesia.transaction(fn ->
      Enum.each(categories, fn category ->
        matches = category["matches"] || []
        name = category["name"] || "Unknown: Unknown"
        [raw_country, raw_league] = case String.split(name, ": ") do
          [c, l] -> [c, l]
          _ -> ["Unknown", "Unknown"]
        end
        country = normalize_country(raw_country)
        league = normalize_league_name(raw_league)
        Logger.debug("Storing matches for sport: #{sport}, raw country: #{raw_country}, normalized country: #{country}, raw league: #{raw_league}, normalized league: #{league}")

        if matches == [] do
          Logger.warning("No matches found for #{sport} in category #{name}")
        end

        Enum.each(matches, fn match ->
          match_id = match["id"]
          start_time = parse_timestamp(match)
          if start_time > now do
            record = {
              table,
              match_id,
              start_time,
              match["localteam"]["name"] || match["player_1"]["name"] || "Unknown",
              match["visitorteam"]["name"] || match["player_2"]["name"] || "Unknown",
              country,
              league,
              parse_markets(match["odds"]),
              match["stats"] || %{},
              now
            }
            :mnesia.write(table, record, :write)
          else
            Logger.debug("Skipping match #{match_id} with past or invalid start_time: #{start_time}")
          end
        end)
      end)
    end)

    case result do
      {:atomic, :ok} -> Logger.info("Stored #{match_count} matches for #{sport}")
      {:aborted, reason} -> Logger.error("Failed to store matches for #{sport}: #{inspect(reason)}")
    end
  end

  defp parse_timestamp(%{"formatted_date" => date, "time" => time} = match) when is_binary(date) and is_binary(time) do
    Logger.debug("Parsing timestamp for match #{match["id"]}: formatted_date=#{date}, time=#{time}")
    case Timex.parse("#{date} #{time}", "%d.%m.%Y %H:%M", :strftime) do
      {:ok, naive_datetime} ->
        case DateTime.from_naive(naive_datetime, "Etc/UTC") do
          {:ok, datetime} ->
            Logger.debug("Parsed timestamp successfully: #{date} #{time} -> #{DateTime.to_unix(datetime, :second)}")
            DateTime.to_unix(datetime, :second)
          {:error, reason} ->
            Logger.error("Failed to convert NaiveDateTime to DateTime for #{date} #{time}: #{inspect(reason)}")
            0
        end
      {:error, reason} ->
        Logger.error("Failed to parse timestamp #{date} #{time}: #{inspect(reason)}")
        0
    end
  end

  defp parse_timestamp(%{"date" => date, "time" => time} = match) when is_binary(date) and is_binary(time) do
    Logger.debug("Parsing timestamp for match #{match["id"]}: date=#{date}, time=#{time}")
    case Timex.parse("#{date} #{time}", "%d.%m.%Y %H:%M", :strftime) do
      {:ok, naive_datetime} ->
        case DateTime.from_naive(naive_datetime, "Etc/UTC") do
          {:ok, datetime} ->
            Logger.debug("Parsed timestamp successfully: #{date} #{time} -> #{DateTime.to_unix(datetime, :second)}")
            DateTime.to_unix(datetime, :second)
          {:error, reason} ->
            Logger.error("Failed to convert NaiveDateTime to DateTime for #{date} #{time}: #{inspect(reason)}")
            0
        end
      {:error, _} ->
        case Timex.parse("#{date} #{@current_year} #{time}", "%b %d %Y %H:%M", :strftime) do
          {:ok, naive_datetime} ->
            case DateTime.from_naive(naive_datetime, "Etc/UTC") do
              {:ok, datetime} ->
                Logger.debug("Parsed fallback timestamp successfully: #{date} #{time} -> #{DateTime.to_unix(datetime, :second)}")
                DateTime.to_unix(datetime, :second)
              {:error, reason} ->
                Logger.error("Failed to convert fallback NaiveDateTime to DateTime for #{date} #{@current_year} #{time}: #{inspect(reason)}")
                0
            end
          {:error, reason} ->
            Logger.error("Failed to parse fallback timestamp #{date} #{@current_year} #{time}: #{inspect(reason)}")
            0
        end
    end
  end

  defp parse_timestamp(match) do
    Logger.error("Invalid timestamp format for match #{match["id"]}: #{inspect(match, pretty: true)}")
    0
  end

  defp parse_markets(odds) when is_list(odds) do
    Enum.reduce(odds, %{}, fn market, acc ->
      market_name = normalize_market_name(market["value"] || market["id"] || "unknown")
      bookmakers = market["bookmakers"] || []
      market_odds =
        Enum.flat_map(bookmakers, fn bookmaker ->
          bookmaker_odds = bookmaker["odds"] || []
          Enum.map(bookmaker_odds, fn odd ->
            case odd do
              %{"name" => name, "value" => value, "stop" => stop} ->
                %{
                  name: name,
                  value: parse_float(value),
                  stop: stop == "True"
                }
              %{"name" => handicap_name, "type" => "handicap", "odds" => sub_odds, "ismain" => ismain, "stop" => stop} ->
                %{
                  name: handicap_name,
                  type: "handicap",
                  ismain: ismain == "True",
                  stop: stop == "True",
                  odds: Enum.map(sub_odds, fn sub_odd ->
                    %{
                      name: sub_odd["name"],
                      value: parse_float(sub_odd["value"]),
                      stop: sub_odd["stop"] == "True"
                    }
                  end)
                }
              %{"name" => total_name, "type" => "total", "odds" => sub_odds, "ismain" => ismain, "stop" => stop} ->
                %{
                  name: total_name,
                  type: "total",
                  ismain: ismain == "True",
                  stop: stop == "True",
                  odds: Enum.map(sub_odds, fn sub_odd ->
                    %{
                      name: sub_odd["name"],
                      value: parse_float(sub_odd["value"]),
                      stop: sub_odd["stop"] == "True"
                    }
                  end)
                }
              _ ->
                Logger.debug("Unrecognized odds format: #{inspect(odd)}")
                nil
            end
          end)
          |> Enum.filter(& &1)
        end)

      if market_odds != [], do: Map.put(acc, market_name, market_odds), else: acc
    end)
  end

  defp parse_markets(_), do: %{}

  defp normalize_market_name(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]/, "_")
    |> String.to_atom()
  end

  defp normalize_market_name(_), do: :unknown

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> 0.0
    end
  end

  defp parse_float(_), do: 0.0

  defp delete_old_matches do
    now = System.system_time(:second)
    four_hours_ago = now - 4 * 3600

    Enum.each(@sports, fn sport ->
      table = String.to_atom("pregame_#{sport}")
      :mnesia.transaction(fn ->
        :mnesia.select(table, [
          {{table, :"$1", :"$2", :_, :_, :_, :_, :_, :_, :_},
           [{:<, :"$2", four_hours_ago}],
           [:"$1"]}
        ])
        |> Enum.each(fn match_id ->
          :mnesia.delete({table, match_id})
        end)
      end)
    end)
  end

  defp broadcast_update(sport) do
    Phoenix.PubSub.broadcast(Boomb.PubSub, "pregame:#{sport}", {:update, sport})
  end

  defp update_timestamp(state, sport, ts) do
    Logger.info("Updating timestamp for #{sport} to #{ts}")
    put_in(state.timestamps[sport], ts)
  end

  defp schedule_initial_fetch do
    Logger.info("Scheduling initial fetch for all sports: #{inspect(@sports)}")
    Enum.each(@sports, fn sport ->
      Process.send_after(self(), {:fetch_sport, sport}, Enum.find_index(@sports, &(&1 == sport)) * @initial_fetch_delay)
    end)
  end

  defp schedule_next_fetch do
    Logger.info("Scheduling next fetch in #{@update_interval}ms")
    Process.send_after(self(), :fetch, @update_interval)
  end

  defp schedule_force_fetch do
    Logger.info("Scheduling force fetch in #{@force_fetch_interval}ms")
    Process.send_after(self(), :force_fetch, @force_fetch_interval)
  end

  defp schedule_delete_old_matches do
    Logger.info("Scheduling delete old matches in #{@delete_interval}ms")
    Process.send_after(self(), :delete_old_matches, @delete_interval)
  end

  defp schedule_health_check do
    Logger.info("Scheduling health check in #{@health_check_interval}ms")
    Process.send_after(self(), :health_check, @health_check_interval)
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
end
