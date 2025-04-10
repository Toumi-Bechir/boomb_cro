defmodule BoombWeb.EventLive do
  use BoombWeb, :live_view

  def mount(%{"event_id" => event_id}, _session, socket) do
    sports = ["soccer", "basket", "tennis", "baseball", "amfootball", "hockey", "volleyball"]
    if connected?(socket) do
      Enum.each(sports, fn sport ->
        Phoenix.PubSub.subscribe(Boomb.PubSub, "events_available:#{sport}")
        # Subscribe to odds updates for the selected event
        Phoenix.PubSub.subscribe(Boomb.PubSub, "odds_update:#{sport}:#{event_id}")
      end)
    end

    # Fetch the selected event
    event = case Boomb.Event.get(event_id) do
      {:ok, event} -> event
      {:error, _} -> nil
    end

    # Group events by sport and competition_name
    grouped_events = Enum.reduce(Boomb.SportsCache.get_sports(), %{}, fn {sport, events}, acc ->
      competitions = events
      |> Enum.group_by(& &1.competition_name)
      |> Enum.sort_by(fn {comp_name, _} -> comp_name end)
      Map.put(acc, sport, competitions)
    end)

    # Fetch odds for the selected event
    odds = case Boomb.OddsCache.get_odds(event_id) do
      {:ok, odds_data} -> odds_data
      {:error, _} -> %{}
    end

    # Fetch all cached odds for score and time display in the left menu
    initial_odds = Boomb.OddsCache.get_all_odds()

    # Determine the sport of the selected event to expand it by default
    expanded_sport = if event, do: event.sport, else: nil

    # Default odds filter
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

  def handle_event("select_event", %{"event_id" => event_id}, socket) do
    sports = socket.assigns.sports
    # Unsubscribe from odds updates for the previous event
    Enum.each(sports, fn sport ->
      Phoenix.PubSub.unsubscribe(Boomb.PubSub, "odds_update:#{sport}:#{socket.assigns.selected_event_id}")
    end)

    # Subscribe to odds updates for the new event
    Enum.each(sports, fn sport ->
      Phoenix.PubSub.subscribe(Boomb.PubSub, "odds_update:#{sport}:#{event_id}")
    end)

    # Fetch the selected event
    event = case Boomb.Event.get(event_id) do
      {:ok, event} -> event
      {:error, _} -> nil
    end

    # Fetch odds for the selected event
    odds = case Boomb.OddsCache.get_odds(event_id) do
      {:ok, odds_data} -> odds_data
      {:error, _} -> %{}
    end

    # Expand the sport of the selected event
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
    updated_odds = Map.put(socket.assigns.all_odds, event_id, %{
      odds: odds,
      score: score,
      period_time: period_time,
      state: state,
    ball_position: ball_position
    })
    
    ball_position_history = if event_id == socket.assigns.selected_event_id do
    current_history = socket.assigns[:ball_position_history] || []
    # Add new position if available, limit history to last 5 positions for performance
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
        odds: %{odds: odds, score: score, period_time: period_time},
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
    "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end

  defp map_ball_position(ball_position, pitch_width \\ 275, pitch_height \\ 160) do
  string = ball_position
  [x, y] = String.split(string, ",")
  
 case String.split(ball_position, ",") do
    # Assuming xy is a tuple {x, y} with values in some range (e.g., 0-100 for both)
    [x, y] ->
      # Normalize to SVG dimensions
      svg_x = String.to_float(x) * 100 #pitch_width / 100
      svg_y = String.to_float(y) * 60 #pitch_height / 100
      {svg_x, svg_y}
    _ ->
      # Default to center if no position
      {pitch_width / 2, pitch_height / 2}
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
  state = String.downcase(state_name)
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
    <path d="M19.52 2.01l-5.53 5.53c-.39.39-.39 1.02 0 1.41l5.53 5.53c.39.39 1.02.39 1.41 0l5.53-5.53c.39-.39.39-1.02 0-1.41l-5.53-5.53c-.39-.39-1.02-.39-1.41 0zM12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/>
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

  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-gray-900 text-gray-100">
      <!-- Left Menu: Scrollable Sidebar -->
      <aside class="w-full md:w-1/4 lg:w-1/5 bg-gray-800 border-r border-gray-700 overflow-y-auto h-screen scrollbar-thin scrollbar-thumb-gray-600 scrollbar-track-gray-800">
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
                    <div class="bg-gray-700 rounded p-2">
                      <div class="flex items-center space-x-2 text-gray-300 text-sm">
                        <span class="truncate"><%= comp_name %></span>
                      </div>
                      <div class="mt-1 space-y-1">
                        <%= for event <- events do %>
                          <a
                            href={~p"/event/#{event.event_id}"}
                            phx-click="select_event"
                            phx-value-event_id={event.event_id}
                            class={"block p-2 rounded text-gray-200 hover:bg-gray-600 flex justify-between items-center #{if @selected_event_id == event.event_id, do: "bg-gray-600", else: ""}"}
                          >
                            <div class="flex items-center space-x-2">
                              <span class="truncate text-sm"><%= event.team1 %></span>
                              <span class="text-xs text-gray-400">vs</span>
                              <span class="truncate text-sm"><%= event.team2 %></span>
                            </div>
                            <div class="flex items-center space-x-2">
                              <%= if odds_data = @all_odds[event.event_id] do %>
                                <span class="text-sm"><%= Map.get(odds_data, :score, "0:0") %></span>
                                <%= if sport in ["soccer", "hockey", "volleyball"] do %>
                                  <span class="text-xs text-gray-400">
                                    <%= format_time(Map.get(odds_data, :period_time, 0)) %>
                                  </span>
                                <% end %>
                              <% else %>
                                <span class="text-sm">0:0</span>
                                <%= if sport in ["soccer", "hockey", "volleyball"] do %>
                                  <span class="text-xs text-gray-400">00:00</span>
                                <% end %>
                              <% end %>
                            </div>
                          </a>
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
      <main class="flex-1 overflow-y-auto h-screen scrollbar-thin scrollbar-thumb-gray-600 scrollbar-track-gray-800 p-4">
        <%= if @event do %>
          <!-- Upper Part: Match Details with Background -->
          <div class="bg-gray-800 p-4 rounded-lg shadow-md mb-4">
            <div class="flex justify-between items-center">
              <h1 class="text-xl font-bold text-white">
                <%= @event.team1 %> vs <%= @event.team2 %>
              </h1>
              <div class="text-right text-gray-300">
                <%= if odds_data = @odds do %>
                  <div class="text-lg font-semibold"><%= Map.get(odds_data, :score, "0:0") %></div>
                  <%= if @event.sport in ["soccer", "hockey", "volleyball"] do %>
                    <div class="text-sm"><%= format_time(Map.get(odds_data, :period_time, 0)) %></div>
                  <% end %>
                <% else %>
                  <div class="text-lg font-semibold">0:0</div>
                  <%= if @event.sport in ["soccer", "hockey", "volleyball"] do %>
                    <div class="text-sm">00:00</div>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Odds Filter -->
          <div class="flex overflow-x-auto space-x-2 mb-4">
            <button
              phx-click="set_odds_filter"
              phx-value-filter="ALL"
              class={"px-4 py-2 rounded-lg text-sm font-medium #{if @odds_filter == "ALL", do: "bg-gray-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}
            >
              ALL
            </button>
            <button
              phx-click="set_odds_filter"
              phx-value-filter="Bet Build"
              class={"px-4 py-2 rounded-lg text-sm font-medium #{if @odds_filter == "Bet Build", do: "bg-gray-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}
            >
              Bet Build
            </button>
            <button
              phx-click="set_odds_filter"
              phx-value-filter="Goal"
              class={"px-4 py-2 rounded-lg text-sm font-medium #{if @odds_filter == "Goal", do: "bg-gray-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}
            >
              Goal
            </button>
            <button
              phx-click="set_odds_filter"
              phx-value-filter="Score"
              class={"px-4 py-2 rounded-lg text-sm font-medium #{if @odds_filter == "Score", do: "bg-gray-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}
            >
              Score
            </button>
            <button
              phx-click="set_odds_filter"
              phx-value-filter="Halftime"
              class={"px-4 py-2 rounded-lg text-sm font-medium #{if @odds_filter == "Halftime", do: "bg-gray-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}
            >
              Halftime
            </button>
            <button
              phx-click="set_odds_filter"
              phx-value-filter="Handicap"
              class={"px-4 py-2 rounded-lg text-sm font-medium #{if @odds_filter == "Handicap", do: "bg-gray-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}
            >
              Handicap
            </button>
            <button
              phx-click="set_odds_filter"
              phx-value-filter="Corners"
              class={"px-4 py-2 rounded-lg text-sm font-medium #{if @odds_filter == "Corners", do: "bg-gray-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}
            >
              Corners
            </button>
            <button
              phx-click="set_odds_filter"
              phx-value-filter="Specials"
              class={"px-4 py-2 rounded-lg text-sm font-medium #{if @odds_filter == "Specials", do: "bg-gray-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}
            >
              Specials
            </button>
            <button
              phx-click="set_odds_filter"
              phx-value-filter="Fast Markets"
              class={"px-4 py-2 rounded-lg text-sm font-medium #{if @odds_filter == "Fast Markets", do: "bg-gray-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}
            >
              Fast Markets
            </button>
            <button
              phx-click="set_odds_filter"
              phx-value-filter="Combos"
              class={"px-4 py-2 rounded-lg text-sm font-medium #{if @odds_filter == "Combos", do: "bg-gray-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}
            >
              Combos
            </button>
            <button
              phx-click="set_odds_filter"
              phx-value-filter="Players"
              class={"px-4 py-2 rounded-lg text-sm font-medium #{if @odds_filter == "Players", do: "bg-gray-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}
            >
              Players
            </button>
          </div>

          <!-- Markets and Odds -->
          <div class="space-y-4">
            <%= if odds_data = @odds do %>
              <%= for {market_id, market_data} <- Map.get(odds_data, :odds, %{}), @odds_filter == "ALL" or market_id in market_ids_for_filter(@odds_filter) do %>
                <div class="bg-gray-800 p-4 rounded-lg">
                  <div class="flex justify-between items-center mb-2">
                    <h3 class="text-md font-medium text-gray-300">
                     <%= get_market_name(@event.sport, market_id) %>
                    </h3>
                    <svg class="w-4 h-4 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <div class="flex space-x-2">
                    <%= for {name, value} <- get_market_odds(odds_data, market_id, []) do %>
                      <div class="flex-1 bg-gray-700 p-2 rounded text-center">
                        <div class="text-gray-400 text-sm"><%= name %></div>
                        <div class="text-white font-semibold"><%= value %></div>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% else %>
              <p class="text-gray-500 text-center">No odds available for this event.</p>
            <% end %>
          </div>
        <% else %>
          <p class="text-gray-500 text-center">Event not found. Please select another event.</p>
        <% end %>
      </main>

      <!-- Right Part: Tracker and Statistics -->
      <aside class="hidden lg:block w-1/4 bg-gray-800 border-l border-gray-700 p-4 overflow-y-auto h-screen scrollbar-thin scrollbar-thumb-gray-600 scrollbar-track-gray-800">
        <div class="space-y-4">
          <!-- Tracker -->
         
<div class="bg-gray-700 p-4 rounded-lg">
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
<% IO.puts "---html -------#{@ball_position_history}--------++"%>
          <!-- Ball Path (if positions exist) -->
          <%= if length(@ball_position_history) > 1 do %>
          <% 
              points={Enum.map(@ball_position_history, fn pos ->
                {x, y} = map_ball_position(pos)
                "#{x},#{y}"
              end) |> Enum.join(" ")}|> IO.inspect 
          %>
            <polyline
              points={Enum.map(@ball_position_history, fn pos ->
                {x, y} = map_ball_position(pos)
                "#{x},#{y}"
              end) |> Enum.join(" ")}
              fill="none"
              stroke="white"
              stroke-width="0.5"
            />
          <% end %>

          <!-- Ball -->
          <% IO.puts "svg circle pos #{inspect List.last(@ball_position_history)}"%>
          <%= if ball_pos = List.first(@ball_position_history) do %>
          
            <% {ball_x, ball_y} = map_ball_position(ball_pos) %>
            <circle
              cx={ball_x}
              cy={ball_y}
              r="1"
              fill="white"
              class="transition-all duration-500 ease-in-out"
            />
            <!-- Center Circle -->
          <circle cx={ball_x} cy={ball_y} r="3" class="transition-all duration-500 ease-in-out" fill="none" stroke="white" stroke-width="0.3" />
            <!-- State Text -->
            <%= if state_code = Map.get(@odds, :state) do %>
              <% state_name = get_state_name(@event.sport, state_code) %>
              <text
                x={ball_x + 5}
                y={ball_y - 2}
                class={"text-xs font-semibold #{get_state_color(state_name)} transition-all duration-500 ease-in-out"}
                fill="currentColor"
              >
                <%= state_name %>
              </text>
            <% end %>
          <% else %>
            <!-- Default Ball Position (Center) -->
            <circle cx="50" cy="30" r="1" fill="white" />
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
    <div class="flex justify-between items-center mt-2">
      <div class="text-gray-300 text-sm">
        <%= @event.team1 %> <%= Map.get(@odds, :score, "0:0") %>
      </div>
      <div class="text-gray-300 text-sm">
        <%= Map.get(@odds, :score, "0:0") %> <%= @event.team2 %>
      </div>
    </div>
  </div>
</div>

          <!-- Statistics -->
          <div class="bg-gray-700 p-4 rounded-lg">
            <h3 class="text-md font-medium text-gray-300 mb-2">Statistics</h3>
            <div class="space-y-2">
              <!-- Static Stats -->
              <div class="flex justify-between items-center">
                <span class="text-gray-400 text-sm">Dangerous Attacks</span>
                <div class="flex items-center space-x-2">
                  <span class="text-gray-300">41</span>
                  <div class="w-32 h-2 bg-gray-600 rounded">
                    <div class="w-3/5 h-full bg-yellow-500 rounded"></div>
                  </div>
                  <span class="text-gray-300">36</span>
                </div>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-gray-400 text-sm">Attacks</span>
                <div class="flex items-center space-x-2">
                  <span class="text-gray-300">18</span>
                  <div class="w-32 h-2 bg-gray-600 rounded">
                    <div class="w-2/5 h-full bg-yellow-500 rounded"></div>
                  </div>
                  <span class="text-gray-300">15</span>
                </div>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-gray-400 text-sm">Possession %</span>
                <div class="flex items-center space-x-2">
                  <span class="text-gray-300">55</span>
                  <div class="w-32 h-2 bg-gray-600 rounded">
                    <div class="w-3/5 h-full bg-yellow-500 rounded"></div>
                  </div>
                  <span class="text-gray-300">45</span>
                </div>
              </div>
              <!-- Action Areas -->
              <div class="mt-4">
                <h4 class="text-sm font-medium text-gray-300 mb-2">Action Areas</h4>
                <div class="flex justify-between items-center">
                  <div class="w-1/3 h-10 bg-gray-600 rounded-l-lg flex items-center justify-center text-gray-300">25%</div>
                  <div class="w-1/3 h-10 bg-gray-600 flex items-center justify-center text-gray-300">48%</div>
                  <div class="w-1/3 h-10 bg-gray-600 rounded-r-lg flex items-center justify-center text-gray-300">27%</div>
                </div>
              </div>
              <!-- Additional Stats -->
              <div class="mt-4 grid grid-cols-2 gap-2">
                <div>
                  <span class="text-gray-400 text-sm">Key Passes</span>
                  <div class="flex justify-between">
                    <span class="text-gray-300">5</span>
                    <span class="text-gray-300">3</span>
                  </div>
                </div>
                <div>
                  <span class="text-gray-400 text-sm">Passing Accuracy</span>
                  <div class="flex justify-between">
                    <span class="text-gray-300">87%</span>
                    <span class="text-gray-300">84%</span>
                  </div>
                </div>
                <div>
                  <span class="text-gray-400 text-sm">Goalkeeper Saves</span>
                  <div class="flex justify-between">
                    <span class="text-gray-300">2</span>
                    <span class="text-gray-300">3</span>
                  </div>
                </div>
                <div>
                  <span class="text-gray-400 text-sm">Crosses</span>
                  <div class="flex justify-between">
                    <span class="text-gray-300">3</span>
                    <span class="text-gray-300">2</span>
                  </div>
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
  defp market_ids_for_filter("ALL"), do: ["1777", "27", "1016", "31"] # Example: Show all markets
  defp market_ids_for_filter("Bet Build"), do: ["1777"]
  defp market_ids_for_filter("Goal"), do: ["1016"]
  defp market_ids_for_filter("Score"), do: ["31"]
  defp market_ids_for_filter("Halftime"), do: ["1777"] # Example: Halftime markets
  defp market_ids_for_filter("Handicap"), do: ["31"]
  defp market_ids_for_filter("Corners"), do: ["31"]
  defp market_ids_for_filter("Specials"), do: ["1016"]
  defp market_ids_for_filter("Fast Markets"), do: ["1777"]
  defp market_ids_for_filter("Combos"), do: ["1777"]
  defp market_ids_for_filter("Players"), do: ["1016"]
  defp market_ids_for_filter(_), do: []
end