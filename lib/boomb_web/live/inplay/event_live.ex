defmodule BoombWeb.EventLive do
  use BoombWeb, :live_view

  def mount(%{"event_id" => event_id}, _session, socket) do
    sports = ["soccer", "basket", "tennis", "baseball", "amfootball", "hockey", "volleyball"]
    IO.puts "-------------------------mount in event live -----------------------------"
    if connected?(socket) do
      Enum.each(sports, fn sport ->
        Phoenix.PubSub.subscribe(Boomb.PubSub, "events_available:#{sport}")
        Phoenix.PubSub.subscribe(Boomb.PubSub, "odds_update:#{sport}:#{event_id}")
      end)
    end

    event = case Boomb.Event.get(event_id) do
      {:ok, event} -> event
      {:error, _} -> nil
    end

    grouped_events = Enum.reduce(Boomb.SportsCache.get_sports(), %{}, fn {sport, events}, acc ->
      competitions = events
      |> Enum.group_by(& &1.competition_name)
      |> Enum.sort_by(fn {comp_name, _} -> comp_name end)
      Map.put(acc, sport, competitions)
    end)

    odds = case Boomb.OddsCache.get_odds(event_id) do
      {:ok, odds_data} ->
        Map.merge(%{state: nil, ball_position: nil}, odds_data)
      {:error, _} ->
        %{state: nil, ball_position: nil}
    end

    initial_odds = Boomb.OddsCache.get_all_odds()
    expanded_sport = if event, do: event.sport, else: nil
    odds_filter = "ALL"

    {:ok, assign(socket,
      grouped_events: grouped_events,
      selected_event_id: event_id,
      event: event,
      odds: odds,
      all_odds: initial_odds,
      sports: sports,
      expanded_sport: expanded_sport,
      odds_filter: odds_filter,
      ball_position_history: []
    )}
  end

  def handle_event("toggle_sport", %{"sport" => sport}, socket) do
    expanded_sport = if socket.assigns.expanded_sport == sport, do: nil, else: sport
    {:noreply, assign(socket, expanded_sport: expanded_sport)}
  end
  def handle_params(params, uri, socket) do

    event_id = params["event_id"]
    IO.puts "------------------ handle paramd --------------------------"
    sports = socket.assigns.sports
    Enum.each(sports, fn sport ->
      Phoenix.PubSub.unsubscribe(Boomb.PubSub, "odds_update:#{sport}:#{socket.assigns.selected_event_id}")
    end)

    Enum.each(sports, fn sport ->
      Phoenix.PubSub.subscribe(Boomb.PubSub, "odds_update:#{sport}:#{event_id}")
    end)

    event = case Boomb.Event.get(event_id) do
      {:ok, event} -> event
      {:error, _} -> nil
    end

    odds = case Boomb.OddsCache.get_odds(event_id) do
      {:ok, odds_data} ->
        Map.merge(%{state: nil, ball_position: nil}, odds_data)
      {:error, _} ->
        %{state: nil, ball_position: nil}
    end

    expanded_sport = if event, do: event.sport, else: socket.assigns.expanded_sport

    {:noreply, assign(socket,
      selected_event_id: event_id,
      event: event,
      odds: odds,
      expanded_sport: expanded_sport
    )}
  end


  def handle_event("select_event", %{"event_id" => event_id}, socket) do
    sports = socket.assigns.sports
    Enum.each(sports, fn sport ->
      Phoenix.PubSub.unsubscribe(Boomb.PubSub, "odds_update:#{sport}:#{socket.assigns.selected_event_id}")
    end)

    Enum.each(sports, fn sport ->
      Phoenix.PubSub.subscribe(Boomb.PubSub, "odds_update:#{sport}:#{event_id}")
    end)

    event = case Boomb.Event.get(event_id) do
      {:ok, event} -> event
      {:error, _} -> nil
    end

    odds = case Boomb.OddsCache.get_odds(event_id) do
      {:ok, odds_data} ->
        Map.merge(%{state: nil, ball_position: nil}, odds_data)
      {:error, _} ->
        %{state: nil, ball_position: nil}
    end

    expanded_sport = if event, do: event.sport, else: socket.assigns.expanded_sport

    {:noreply, assign(socket,
      selected_event_id: event_id,
      event: event,
      odds: odds,
      expanded_sport: expanded_sport
    )}
  end

  def handle_event("set_odds_filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, odds_filter: filter)}
  end

  def handle_info(%{events: _events}, socket) do
    sports_data = Boomb.SportsCache.get_sports()
    grouped_events = Enum.reduce(sports_data, %{}, fn {sport, events}, acc ->
      competitions = events
      |> Enum.group_by(& &1.competition_name)
      |> Enum.sort_by(fn {comp_name, _} -> comp_name end)
      Map.put(acc, sport, competitions)
    end)
    {:noreply, assign(socket, grouped_events: grouped_events)}
  end

  def handle_info(%{event_id: event_id, odds: odds, score: score, period_time: period_time, state: state, ball_position: ball_position}, socket) do
    if Application.get_env(:boomb, :env) == :dev do
      Logger.debug("Received odds_update for event #{event_id}: ball_position=#{inspect(ball_position)}, state=#{inspect(state)}")
    end

    updated_odds_data = %{
      odds: odds,
      score: score,
      period_time: period_time,
      state: state,
      ball_position: ball_position
    }
    updated_odds = Map.put(socket.assigns.all_odds, event_id, updated_odds_data)

    ball_position_history = if event_id == socket.assigns.selected_event_id do
      current_history = socket.assigns[:ball_position_history] || []
      if ball_position do
        new_history = [ball_position | current_history] |> Enum.take(7)
        new_history
      else
        current_history
      end
    else
      socket.assigns[:ball_position_history] || []
    end

    if event_id == socket.assigns.selected_event_id do
      {:noreply, assign(socket,
        odds: updated_odds_data,
        all_odds: updated_odds,
        ball_position_history: ball_position_history
      )}
    else
      {:noreply, assign(socket, all_odds: updated_odds, ball_position_history: ball_position_history)}
    end
  end

  defp format_time(seconds) do
    minutes = div(seconds, 60)
    seconds = rem(seconds, 60)
    "#{minutes}'#{String.pad_leading(to_string(seconds), 2, "0")}\""
  end

  defp map_ball_position(ball_position, _pitch_width \\ 100, _pitch_height \\ 60) do
    case String.split(ball_position, ",") do
      [x, y] ->
        try do
          svg_x = parse_to_float(x) * 100
          svg_y = parse_to_float(y) * 60
          {svg_x, svg_y}
        rescue
          _ -> {50, 30} # Center of the pitch
        end
      _ ->
        {50, 30} # Center of the pitch
    end
  end

  defp parse_to_float(binary) when is_binary(binary) do
    case Float.parse(binary) do
      {float, _} -> float
      :error ->
        case Integer.parse(binary) do
          {int, _} -> int * 1.0
          :error -> raise ArgumentError, "Invalid float representation: #{binary}"
        end
    end
  end

  defp get_market_odds(odds_data, market_id, default \\ nil) do
    case odds_data do
      %{odds: odds} ->
        case Map.get(odds, market_id) do
          nil -> default
          market ->
            market_odds = Enum.map(market.odds, fn odd ->
              {odd.name, odd.value}
            end)
            Map.new(market_odds)
        end
      _ -> default
    end
  end

  defp get_state_color(state_name) do
    state = if state_name, do: String.downcase(state_name), else: ""
    cond do
      String.contains?(state, "attack") -> "text-orange-500"
      String.contains?(state, "dangerous") -> "text-red-500"
      String.contains?(state, "possession") -> "text-green-500"
      String.contains?(state, "free kick") -> "text-yellow-500"
      String.contains?(state, "corner") -> "text-blue-500"
      true -> "text-white"
    end
  end

  defp sport_background("soccer"), do: "bg-green-700"
  defp sport_background("basket"), do: "bg-yellow-700"
  defp sport_background("tennis"), do: "bg-green-800"
  defp sport_background("baseball"), do: "bg-orange-700"
  defp sport_background("amfootball"), do: "bg-blue-700"
  defp sport_background("hockey"), do: "bg-gray-600"
  defp sport_background("volleyball"), do: "bg-blue-600"
  defp sport_background(_sport), do: "bg-gray-700"

  defp sport_icon("soccer"), do: """
  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v2h-2zm0 4h2v6h-2zm4-4h2v2h-2zm0 4h2v6h-2zm-8-4h2v2H7zm0 4h2v6H7z"/>
  </svg>
  """

  defp sport_icon("basket"), do: """
  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v2h-2zm0 4h2v6h-2zm4-4h2v2h-2zm0 4h2v6h-2zm-8-4h2v2H7zm0 4h2v6H7z"/>
  </svg>
  """

  defp sport_icon("tennis"), do: """
  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
    <path d="M19.52 2.01l-5.53 5.53c-.39.39-.39 1.02 0 1.41l5.53 5.53c-.39.39 1.02.39 1.41 0l5.53-5.53c-.39-.39.39-1.02 0-1.41l-5.53-5.53c-.39-.39-1.02-.39-1.41 0zM12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/>
  </svg>
  """

  defp sport_icon("baseball"), do: """
  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v2h-2zm0 4h2v6h-2zm4-4h2v2h-2zm0 4h2v6h-2zm-8-4h2v2H7zm0 4h2v6H7z"/>
  </svg>
  """

  defp sport_icon("amfootball"), do: """
  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v2h-2zm0 4h2v6h-2zm4-4h2v2h-2zm0 4h2v6h-2zm-8-4h2v2H7zm0 4h2v6H7z"/>
  </svg>
  """

  defp sport_icon("hockey"), do: """
  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v2h-2zm0 4h2v6h-2zm4-4h2v2h-2zm0 4h2v6h-2zm-8-4h2v2H7zm0 4h2v6H7z"/>
  </svg>
  """

  defp sport_icon("volleyball"), do: """
  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v2h-2zm0 4h2v6h-2zm4-4h2v2h-2zm0 4h2v6h-2zm-8-4h2v2H7zm0 4h2v6H7z"/>
  </svg>
  """

  defp sport_icon(_sport), do: """
  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/>
  </svg>
  """

  defp sport_count(grouped_events, sport) do
    case Map.get(grouped_events, sport) do
      nil -> 0
      competitions ->
        Enum.reduce(competitions, 0, fn {_, events}, acc -> acc + length(events) end)
    end
  end

  defp get_market_name(sport, market_id) do
    case sport do
      "soccer" -> Boomb.MarketDictionaries.get_soccer_market_name(market_id)
      "basket" -> Boomb.MarketDictionaries.get_basket_market_name(market_id)
      "baseball" -> Boomb.MarketDictionaries.get_baseball_market_name(market_id)
      "hockey" -> Boomb.MarketDictionaries.get_hockey_market_name(market_id)
      "volleyball" -> Boomb.MarketDictionaries.get_volleyball_market_name(market_id)
      _ -> "Unknown Market"
    end
  end

  defp get_state_name(sport, state_code) do
    case sport do
      "soccer" -> Boomb.StateDictionaries.get_soccer_state_name(state_code)
      "basket" -> Boomb.StateDictionaries.get_basket_state_name(state_code)
      "tennis" -> Boomb.StateDictionaries.get_tennis_state_name(state_code)
      "baseball" -> Boomb.StateDictionaries.get_baseball_state_name(state_code)
      "amfootball" -> Boomb.StateDictionaries.get_amfootball_state_name(state_code)
      "hockey" -> Boomb.StateDictionaries.get_hockey_state_name(state_code)
      "volleyball" -> Boomb.StateDictionaries.get_volleyball_state_name(state_code)
      _ -> "Unknown State"
    end
  end

  defp market_ids_for_filter("ALL"), do: ["1777", "27", "1016", "31"]
  defp market_ids_for_filter("Bet Build"), do: ["1777"]
  defp market_ids_for_filter("Goal"), do: ["1016"]
  defp market_ids_for_filter("Score"), do: ["31"]
  defp market_ids_for_filter("Halftime"), do: ["1777"]
  defp market_ids_for_filter("Handicap"), do: ["31"]
  defp market_ids_for_filter("Corners"), do: ["31"]
  defp market_ids_for_filter("Specials"), do: ["1016"]
  defp market_ids_for_filter("Fast Markets"), do: ["1777"]
  defp market_ids_for_filter("Combos"), do: ["1777"]
  defp market_ids_for_filter("Players"), do: ["1016"]
  defp market_ids_for_filter(_), do: []

  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-[#1a2e40] text-white">
      <!-- Left Menu: Scrollable Sidebar -->
      <aside class="w-full md:w-1/4 lg:w-1/5 bg-[#23384a] border-r border-[#0d2235] overflow-y-auto h-screen scrollbar-thin scrollbar-thumb-gray-600 scrollbar-track-gray-800">
        <div class="p-2 space-y-2">
          <%= for {sport, competitions} <- @grouped_events do %>
            <div>
              <!-- Sport Header -->
              <button
                phx-click="toggle_sport"
                phx-value-sport={sport}
                class={"flex justify-between items-center w-full p-2 text-white font-semibold rounded #{sport_background(sport)}"}
              >
                <div class="flex items-center space-x-2">
                  <%= raw(sport_icon(sport)) %>
                  <span class="uppercase text-sm"><%= String.upcase(sport) %> <%= sport_count(@grouped_events, sport) %></span>
                </div>
                <svg class={"w-4 h-4 transform #{if @expanded_sport == sport, do: "rotate-180", else: ""}"} fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
              </button>

              <!-- Competitions and Matches (Collapsible) -->
              <%= if @expanded_sport == sport do %>
                <div class="space-y-1">
                  <%= for {comp_name, events} <- competitions do %>
                    <div class="bg-[#2d4657] rounded p-2">
                      <div class="flex items-center space-x-2 text-gray-300 text-sm">
                        <span class="truncate"><%= comp_name %></span>
                      </div>
                     <div class="mt-1 space-y-1">
  <%= for event <- events do %>
  
    
    
      <!-- Team 1 on its own line -->
      <div class="flex justify-between items-center">
        <span class="truncate text-sm">
        <%= live_patch(event.team1, to: URI.parse("/event/#{event.event_id}")) %>
        </span>
        <%= if odds_data = @all_odds[event.event_id] do %>
          <span class="text-sm"><%= Map.get(odds_data, :score, "0:0") %></span>
        <% else %>
          <span class="text-sm">0:0</span>
        <% end %>
      </div>
      
      <!-- Team 2 on its own line -->
      <div class="flex justify-between items-center mt-1">
        <span class="truncate text-sm">
        <%= live_patch(event.team2, to: URI.parse("/event/#{event.event_id}")) %>
        </span>
        <%= if sport in ["soccer", "hockey", "volleyball"] do %>
          <%= if odds_data = @all_odds[event.event_id] do %>
            <span class="text-xs text-gray-400">
              <%= format_time(Map.get(odds_data, :period_time, 0)) %>
            </span>
          <% else %>
            <span class="text-xs text-gray-400">00:00</span>
          <% end %>
        <% end %>
      </div>
    
  <% end %>
</div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </aside>

      <!-- Middle Part: Markets and Odds -->
      <main class="flex-1 overflow-y-auto h-screen scrollbar-thin scrollbar-thumb-gray-600 scrollbar-track-gray-800 p-2">
        <%= if @event do %>
          <!-- Header: Match Details -->
          <div class="bg-[#23384a] p-2 rounded-lg shadow-md mb-2">
            <div class="flex justify-between items-center">
              <h1 class="text-lg font-bold text-white">
                <%= @event.team1 %> vs <%= @event.team2 %>
              </h1>
              <div class="text-right text-gray-300">
                <%= if odds_data = @odds do %>
                  <div class="text-md font-semibold"><%= Map.get(odds_data, :score, "0:0") %></div>
                  <%= if @event.sport in ["soccer", "hockey", "volleyball"] do %>
                    <div class="text-xs"><%= format_time(Map.get(odds_data, :period_time, 0)) %></div>
                  <% end %>
                <% else %>
                  <div class="text-md font-semibold">0:0</div>
                  <%= if @event.sport in ["soccer", "hockey", "volleyball"] do %>
                    <div class="text-xs">00:00</div>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Odds Filter -->
          <div class="flex overflow-x-auto space-x-1 mb-2">
            <button
              phx-click="set_odds_filter"
              phx-value-filter="ALL"
              class={"px-3 py-1 rounded-lg text-xs font-medium #{if @odds_filter == "ALL", do: "bg-[#00b3ff] text-white", else: "bg-[#2d4657] text-gray-300 hover:bg-[#3a586a]"}"}
            >
              ALL
            </button>
            <button
              phx-click="set_odds_filter"
              phx-value-filter="Same Game Parlay"
              class={"px-3 py-1 rounded-lg text-xs font-medium #{if @odds_filter == "Same Game Parlay", do: "bg-[#00b3ff] text-white", else: "bg-[#2d4657] text-gray-300 hover:bg-[#3a586a]"}"}
            >
              Same Game Parlay
            </button>
            <button
              phx-click="set_odds_filter"
              phx-value-filter="Flash Bets"
              class={"px-3 py-1 rounded-lg text-xs font-medium #{if @odds_filter == "Flash Bets", do: "bg-[#00b3ff] text-white", else: "bg-[#2d4657] text-gray-300 hover:bg-[#3a586a]"}"}
            >
              Flash Bets
            </button>
            <button
              phx-click="set_odds_filter"
              phx-value-filter="Asian Lines"
              class={"px-3 py-1 rounded-lg text-xs font-medium #{if @odds_filter == "Asian Lines", do: "bg-[#00b3ff] text-white", else: "bg-[#2d4657] text-gray-300 hover:bg-[#3a586a]"}"}
            >
              Asian Lines
            </button>
            <button
              phx-click="set_odds_filter"
              phx-value-filter="Corners/Cards"
              class={"px-3 py-1 rounded-lg text-xs font-medium #{if @odds_filter == "Corners/Cards", do: "bg-[#00b3ff] text-white", else: "bg-[#2d4657] text-gray-300 hover:bg-[#3a586a]"}"}
            >
              Corners/Cards
            </button>
            <button
              phx-click="set_odds_filter"
              phx-value-filter="Goals"
              class={"px-3 py-1 rounded-lg text-xs font-medium #{if @odds_filter == "Goals", do: "bg-[#00b3ff] text-white", else: "bg-[#2d4657] text-gray-300 hover:bg-[#3a586a]"}"}
            >
              Goals
            </button>
            <button
              phx-click="set_odds_filter"
              phx-value-filter="Half"
              class={"px-3 py-1 rounded-lg text-xs font-medium #{if @odds_filter == "Half", do: "bg-[#00b3ff] text-white", else: "bg-[#2d4657] text-gray-300 hover:bg-[#3a586a]"}"}
            >
              Half
            </button>
          </div>

          <!-- Markets and Odds -->
          <div class="space-y-2">
            <%= if odds_data = @odds do %>
              <%= for {market_id, market_data} <- Map.get(odds_data, :odds, %{}), @odds_filter == "ALL" or market_id in market_ids_for_filter(@odds_filter) do %>
                <div class="bg-[#23384a] p-2 rounded-lg">
                  <div class="flex justify-between items-center mb-1">
                    <h3 class="text-xs font-medium text-gray-300">
                    
                      <%= get_market_name(@event.sport, market_id) %>
                    </h3>
                    <svg class="w-4 h-4 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <div class="grid grid-cols-2 md:grid-cols-3 gap-1">
                    <%= for {name, value} <- get_market_odds(odds_data, market_id, []) do %>
                      <button class="w-full py-1 bg-[#2d6b3d] hover:bg-[#3a7a4a] rounded-sm text-xs font-bold">
                        <%= name %> <span class="block"><%= value %></span>
                      </button>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% else %>
              <p class="text-gray-500 text-center text-xs">No odds available for this event.</p>
            <% end %>
          </div>
        <% else %>
          <p class="text-gray-500 text-center text-xs">Event not found. Please select another event.</p>
        <% end %>
      </main>

      <!-- Right Part: Tracker and Statistics -->
      <aside class="hidden lg:block w-1/4 bg-[#23384a] border-l border-[#0d2235] p-2 overflow-y-auto h-screen scrollbar-thin scrollbar-thumb-gray-600 scrollbar-track-gray-800">
        <div class="space-y-2">
          <!-- Tracker -->
          <div class="bg-[#2d4657] p-2 rounded-lg">
            <div class="relative">
              <!-- Dynamic Soccer Pitch -->
              <%= if @event && @event.sport == "soccer" do %>
                <div class="w-full h-40 bg-green-800 rounded-lg relative overflow-hidden">
                  <!-- SVG Pitch -->
                  <svg class="w-full h-full" viewBox="0 0 100 60" preserveAspectRatio="xMidYMid meet">
                    <!-- Pitch Outline -->
                    <rect x="0" y="0" width="100" height="60" fill="none" stroke="white" stroke-width="0.5" />
                    <!-- Center Line -->
                    <line x1="50" y1="0" x2="50" y2="60" stroke="white" stroke-width="0.5" stroke-dasharray="2,2" />
                    <!-- Penalty Areas -->
                    <rect x="0" y="15" width="10" height="30" fill="none" stroke="white" stroke-width="0.5" />
                    <rect x="90" y="15" width="10" height="30" fill="none" stroke="white" stroke-width="0.5" />
                    <!-- Goal Areas -->
                    <rect x="0" y="22.5" width="5" height="15" fill="none" stroke="white" stroke-width="0.5" />
                    <rect x="95" y="22.5" width="5" height="15" fill="none" stroke="white" stroke-width="0.5" />
                    <!-- Goals -->
                    <rect x="0" y="25" width="1" height="10" fill="white" />
                    <rect x="99" y="25" width="1" height="10" fill="white" />
                    <!-- Ball Path (if positions exist) -->
                    <%= if length(@ball_position_history) > 1 do %>
                      <% points = Enum.map(@ball_position_history, fn pos ->
                           {x, y} = map_ball_position(pos)
                           "#{x},#{y}"
                         end) |> Enum.join(" ") %>
                      <polyline points={points} fill="none" stroke="white" stroke-width="0.5" />
                    <% end %>
                    <!-- Ball -->
                    <%= if ball_pos = List.first(@ball_position_history) do %>
                      <% {ball_x, ball_y} = map_ball_position(ball_pos) %>
                      <circle cx={ball_x} cy={ball_y} r="1" fill="white" class="transition-all duration-500 ease-in-out" />
                      <circle cx={ball_x} cy={ball_y} r="3" class="transition-all duration-500 ease-in-out" fill="none" stroke="white" stroke-width="0.3" />
                      <% state_code = Map.get(@odds, :state) %>
                      <% state_name = if state_code do
                           get_state_name(@event.sport, state_code)
                         else
                           "No State Available"
                         end %>
                      <text x={ball_x + 5} y={ball_y - 2} class={"font-semibold #{get_state_color(state_name)} transition-all duration-500 ease-in-out"} fill="currentColor" style="font-size: 5px;">
                        <%= state_name %>
                      </text>
                    <% else %>
                      <circle cx="50" cy="30" r="1" fill="white" />
                      <text x="55" y="28" class="text-xs font-semibold text-gray-400" fill="currentColor">
                        No State Available
                      </text>
                    <% end %>
                  </svg>
                  <!-- Time Display -->
                  <div class="absolute top-2 left-2 bg-black bg-opacity-50 text-white text-xs px-2 py-1 rounded">
                    <%= format_time(Map.get(@odds, :period_time, 0)) %>
                  </div>
                </div>
              <% else %>
                <div class="w-full h-40 bg-green-800 rounded-lg flex justify-center items-center">
                  <div class="text-gray-400 text-sm">Tracker Not Available for This Sport</div>
                </div>
              <% end %>

              <!-- Match Info -->
              <div class="flex justify-between items-center mt-1">
                <div class="text-gray-300 text-xs">
                  <%= @event.team1 %>
                </div>
                <div class="text-gray-300 text-xs">
                  <%= @event.team2 %>
                </div>
              </div>
              <div class="flex justify-between items-center">
                <div class="text-gray-300 text-xs">
                  <%= Map.get(@odds, :score, "0:0") %>
                </div>
                <div class="text-gray-300 text-xs">
                  <%= Map.get(@odds, :score, "0:0") %>
                </div>
              </div>
            </div>
          </div>

          <!-- Tabs: Stats, Timeline, Lineups, Standings -->
          <div class="flex space-x-1 mb-2">
            <button class="px-3 py-1 bg-[#2d4657] text-gray-300 hover:bg-[#3a586a] rounded-sm text-xs font-medium">
              STATS
            </button>
            <button class="px-3 py-1 bg-[#2d4657] text-gray-300 hover:bg-[#3a586a] rounded-sm text-xs font-medium">
              TIMELINE
            </button>
            <button class="px-3 py-1 bg-[#2d4657] text-gray-300 hover:bg-[#3a586a] rounded-sm text-xs font-medium">
              LINEUPS
            </button>
            <button class="px-3 py-1 bg-[#2d4657] text-gray-300 hover:bg-[#3a586a] rounded-sm text-xs font-medium">
              STANDINGS
            </button>
          </div>

          <!-- Statistics -->
          <div class="bg-[#2d4657] p-2 rounded-lg">
            <div class="space-y-2">
              <!-- Static Stats -->
              <div class="flex justify-between items-center">
                <span class="text-gray-400 text-xs">Attacks</span>
                <div class="flex items-center space-x-2">
                  <span class="text-gray-300 text-xs">39</span>
                  <div class="w-32 h-2 bg-gray-600 rounded">
                    <div class="w-[55%] h-full bg-yellow-500 rounded"></div>
                  </div>
                  <span class="text-gray-300 text-xs">32</span>
                </div>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-gray-400 text-xs">Dangerous Attacks</span>
                <div class="flex items-center space-x-2">
                  <span class="text-gray-300 text-xs">31</span>
                  <div class="w-32 h-2 bg-gray-600 rounded">
                    <div class="w-[50%] h-full bg-yellow-500 rounded"></div>
                  </div>
                  <span class="text-gray-300 text-xs">30</span>
                </div>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-gray-400 text-xs">Possession %</span>
                <div class="flex items-center space-x-2">
                  <span class="text-gray-300 text-xs">52</span>
                  <div class="w-32 h-2 bg-gray-600 rounded">
                    <div class="w-[52%] h-full bg-yellow-500 rounded"></div>
                  </div>
                  <span class="text-gray-300 text-xs">48</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </aside>
    </div>
    """
  end

  # Helper to determine which market IDs to show for each filter
  defp market_ids_for_filter("ALL"), do: ["1777", "27", "1016", "31"]
  defp market_ids_for_filter("Bet Build"), do: ["1777"]
  defp market_ids_for_filter("Goal"), do: ["1016"]
  defp market_ids_for_filter("Score"), do: ["31"]
  defp market_ids_for_filter("Halftime"), do: ["1777"]
  defp market_ids_for_filter("Handicap"), do: ["31"]
  defp market_ids_for_filter("Corners"), do: ["31"]
  defp market_ids_for_filter("Specials"), do: ["1016"]
  defp market_ids_for_filter("Fast Markets"), do: ["1777"]
  defp market_ids_for_filter("Combos"), do: ["1777"]
  defp market_ids_for_filter("Players"), do: ["1016"]
  defp market_ids_for_filter(_), do: []
end