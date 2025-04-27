defmodule BoombWeb.OverviewLive111 do
  use BoombWeb, :live_view
  require Logger

  def mount(_params, _session, socket) do
    IO.puts "********************** mount in BoombWeb.OverviewLive loaded *********************************"
    sports = ["soccer", "basket", "tennis", "baseball", "amfootball", "hockey", "volleyball"]
    if connected?(socket) do
      Enum.each(sports, fn sport ->
        Phoenix.PubSub.subscribe(Boomb.PubSub, "events_available:#{sport}")
      end)
    end

    sports_data = Boomb.SportsCache.get_sports()
    IO.inspect sports_data
        events_by_competition = organize_events_by_competition(sports_data, nil) # Initially show all sports
    # Fetch all cached odds data for initial display
    initial_odds = Boomb.OddsCache.get_all_odds()
    # Subscribe to updates for all events currently displayed
    events_by_competition = update_event_subscriptions([], events_by_competition, sports)
    {:ok, assign(socket,
      events_by_competition: events_by_competition,
      odds: initial_odds,
      sports: sports,
      sports_data: sports_data, # Store sports_data in assigns
      selected_sport: "soccer" #nil # Initially show all sports
    )}
  end

  def handle_event("filter_by_sport", %{"sport" => sport}, socket) do
    IO.puts "---------------handle event filter   -------#{inspect sport}---- --------------------------"
    selected_sport = if sport == socket.assigns.selected_sport, do: nil, else: sport
    sports_data = Boomb.SportsCache.get_sports()
    events_by_competition = organize_events_by_competition(sports_data, selected_sport)
    events_by_competition = update_event_subscriptions(socket.assigns.events_by_competition, events_by_competition, socket.assigns.sports)
    {:noreply, assign(socket,
      events_by_competition: events_by_competition,
      sports_data: sports_data, # Update sports_data
      selected_sport: selected_sport
    )}
  end

  def handle_info(%{events: _events}, socket) do
    Logger.debug("Received events_available update for sport")
    sports_data = Boomb.SportsCache.get_sports()
    events_by_competition = organize_events_by_competition(sports_data, socket.assigns.selected_sport)
    updated_events = update_event_subscriptions(socket.assigns.events_by_competition, events_by_competition, socket.assigns.sports)
    {:noreply, assign(socket,
      events_by_competition: updated_events,
      sports_data: sports_data # Update sports_data
    )}
  end

  def handle_info(%{event_id: event_id, odds: odds, score: score, period_time: period_time}, socket) do
    updated_odds = Map.put(socket.assigns.odds, event_id, %{
      odds: odds,
      score: score,
      period_time: period_time
    })
    {:noreply, assign(socket, odds: updated_odds)}
  end

  defp organize_events_by_competition(sports_data, selected_sport) do
    filtered_data = if selected_sport do
      Map.take(sports_data, [selected_sport])
    else
      sports_data
    end

    filtered_data
    |> Enum.flat_map(fn {sport, events} ->
      events
      |> Enum.group_by(& &1.competition_name)
      |> Enum.map(fn {comp_name, comp_events} -> {sport, comp_name, comp_events} end)
    end)
    |> Enum.sort_by(fn {sport, comp_name, _} -> {sport, comp_name} end)
  end

  defp update_event_subscriptions(old_events, new_events, sports) do
    old_event_ids = extract_event_ids(old_events)
    new_event_ids = extract_event_ids(new_events)

    # Unsubscribe from events no longer present
    events_to_unsubscribe = old_event_ids -- new_event_ids
    Enum.each(events_to_unsubscribe, fn event_id ->
      Enum.each(sports, fn sport ->
        Phoenix.PubSub.unsubscribe(Boomb.PubSub, "odds_update:#{sport}:#{event_id}")
      end)
    end)

    # Subscribe to new events
    events_to_subscribe = new_event_ids -- old_event_ids
    Enum.each(new_events, fn {sport, _comp_name, comp_events} ->
      comp_event_ids = Enum.map(comp_events, & &1.event_id)
      events_to_subscribe_in_comp = comp_event_ids -- old_event_ids
      Enum.each(events_to_subscribe_in_comp, fn event_id ->
        Phoenix.PubSub.subscribe(Boomb.PubSub, "odds_update:#{sport}:#{event_id}")
      end)
    end)

    new_events
  end

  defp extract_event_ids(events_by_competition) do
    events_by_competition
    |> Enum.flat_map(fn {_sport, _comp_name, events} -> Enum.map(events, & &1.event_id) end)
    |> Enum.uniq()
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

  defp format_time(seconds) do
    minutes = div(seconds, 60)
    seconds = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end

  defp sport_icon("soccer"), do: """
  <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v2h-2zm0 4h2v6h-2zm4-4h2v2h-2zm0 4h2v6h-2zm-8-4h2v2H7zm0 4h2v6H7z"/>
  </svg>
  """

  defp sport_icon("basket"), do: """
  <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v2h-2zm0 4h2v6h-2zm4-4h2v2h-2zm0 4h2v6h-2zm-8-4h2v2H7zm0 4h2v6H7z"/>
  </svg>
  """

  defp sport_icon("tennis"), do: """
  <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
    <path d="M19.52 2.01l-5.53 5.53c-.39.39-.39 1.02 0 1.41l5.53 5.53c.39.39 1.02.39 1.41 0l5.53-5.53c.39-.39.39-1.02 0-1.41l-5.53-5.53c-.39-.39-1.02-.39-1.41 0zM12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/>
  </svg>
  """

  defp sport_icon("baseball"), do: """
  <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v2h-2zm0 4h2v6h-2zm4-4h2v2h-2zm0 4h2v6h-2zm-8-4h2v2H7zm0 4h2v6H7z"/>
  </svg>
  """

  defp sport_icon("amfootball"), do: """
  <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v2h-2zm0 4h2v6h-2zm4-4h2v2h-2zm0 4h2v6h-2zm-8-4h2v2H7zm0 4h2v6H7z"/>
  </svg>
  """

  defp sport_icon("hockey"), do: """
  <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v2h-2zm0 4h2v6h-2zm4-4h2v2h-2zm0 4h2v6h-2zm-8-4h2v2H7zm0 4h2v6H7z"/>
  </svg>
  """

  defp sport_icon("volleyball"), do: """
  <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v2h-2zm0 4h2v6h-2zm4-4h2v2h-2zm0 4h2v6h-2zm-8-4h2v2H7zm0 4h2v6H7z"/>
  </svg>
  """

  defp sport_icon(_sport), do: """
  <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/>
  </svg>
  """

  defp sport_count(sports_data, sport) do
    case Map.get(sports_data, sport) do
      nil -> 0
      events -> length(events)
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-gray-100">
      <!-- Top Navigation Menu -->
      <nav class="bg-gray-800 p-2 shadow-md">
        <div class="flex space-x-2 overflow-x-auto scrollbar-thin scrollbar-thumb-gray-600 scrollbar-track-gray-800">
          <!-- All Sports Button -->
          <button
            phx-click="filter_by_sport"
            phx-value-sport="all"
            class={"flex items-center space-x-1 px-3 py-2 rounded-lg #{if @selected_sport == nil, do: "bg-gray-600", else: "bg-gray-700 hover:bg-gray-600"}"}
          >
            <span class="text-sm font-medium">ALL</span>
            <span class="text-xs bg-gray-500 rounded-full px-2 py-1">
              <%= Enum.sum(Enum.map(@sports, fn sport -> sport_count(@sports_data, sport) end)) %>
            </span>
          </button>

          <!-- Sport Buttons -->
          <%= for sport <- @sports do %>
            <button
              phx-click="filter_by_sport"
              phx-value-sport={sport}
              class={"flex items-center space-x-1 px-3 py-2 rounded-lg #{if @selected_sport == sport, do: "bg-gray-600", else: "bg-gray-700 hover:bg-gray-600"}"}
            >
              <%= raw(sport_icon(sport)) %>
              <span class="text-sm font-medium hidden md:block"><%= String.capitalize(sport) %></span>
              <span class="text-xs bg-gray-500 rounded-full px-2 py-1">
                <%= sport_count(@sports_data, sport) %>
              </span>
            </button>
          <% end %>
        </div>
      </nav>

      <!-- Main Content -->
      <div class="p-4">
        <h1 class="text-2xl font-bold mb-4 hidden">Live Events Overview</h1>
        <%= if Enum.empty?(@events_by_competition) do %>
          <p class="text-gray-500 text-center">No live events available at the moment. Please check back later.</p>
        <% else %>
          <div class="space-y-6">
            <%= for {sport, competition_name, events} <- @events_by_competition do %>
              <div>
                <h2 class="text-lg font-semibold text-white bg-gray-700 p-2 rounded">
                  <%= String.capitalize(sport) %> - <%= competition_name %>
                </h2>
                <div class="overflow-x-auto">
                  <table class="w-full text-white text-sm">
                    <thead>
                      <tr class="bg-gray-600">
                        <th class="p-2 text-left">Match</th>
                        <th class="p-2">Score</th>
                        <%= if sport in ["soccer", "hockey", "volleyball"] do %>
                          <th class="p-2">Time</th>
                        <% end %>
                        <th class="p-2">1X2 Bet</th>
                        <th class="p-2">Rest of the Match</th>
                        <th class="p-2">Next Goal</th>
                        <th class="p-2">Over/Under</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for event <- events do %>
                        <tr class="border-b border-gray-600 hover:bg-gray-800">
                          <td class="p-2">
                            <a href={~p"/event/#{event.event_id}"} class="text-blue-400 hover:underline">
                              <%= event.team1 %> vs <%= event.team2 %>
                            </a>
                            <span class="text-xs text-gray-400 block">
                              <%= case event.period_code do
                                 0 -> "(Not Started)"
                                 1 -> "(1st Half)"
                                 _ -> "(Live)"
                               end %>
                            </span>
                          </td>
                          <td class="p-2 text-center">
                            <%= if odds_data = @odds[event.event_id] do %>
                              <%= Map.get(odds_data, :score, "0:0") %>
                            <% else %>
                              0:0
                            <% end %>
                          </td>
                          <%= if sport in ["soccer", "hockey", "volleyball"] do %>
                            <td class="p-2 text-center">
                              <%= if odds_data = @odds[event.event_id] do %>
                                <%= format_time(Map.get(odds_data, :period_time, 0)) %>
                              <% else %>
                                "00:00"
                              <% end %>
                            </td>
                          <% end %>
                          <td class="p-2 text-center">
                            <%= if odds_data = @odds[event.event_id] do %>
                              <%= with market <- get_market_odds(odds_data, "1777", %{"1" => "-", "X" => "-", "2" => "-"}) do %>
                                <div class="flex justify-around">
                                  <span><%= market["1"] %></span>
                                  <span><%= market["X"] %></span>
                                  <span><%= market["2"] %></span>
                                </div>
                              <% end %>
                            <% else %>
                              <div class="flex justify-around">
                                <span>-</span>
                                <span>-</span>
                                <span>-</span>
                              </div>
                            <% end %>
                          </td>
                          <td class="p-2 text-center">
                            <%= if odds_data = @odds[event.event_id] do %>
                              <%= with market <- get_market_odds(odds_data, "27", %{"1" => "-", "X" => "-", "2" => "-"}) do %>
                                <div class="flex justify-around">
                                  <span><%= market["1"] %></span>
                                  <span><%= market["X"] %></span>
                                  <span><%= market["2"] %></span>
                                </div>
                              <% end %>
                            <% else %>
                              <div class="flex justify-around">
                                <span>-</span>
                                <span>-</span>
                                <span>-</span>
                              </div>
                            <% end %>
                          </td>
                          <td class="p-2 text-center">
                            <%= if odds_data = @odds[event.event_id] do %>
                              <%= with market <- get_market_odds(odds_data, "1016", %{"1" => "-", "No goal" => "-", "2" => "-"}) do %>
                                <div class="flex justify-around">
                                  <span><%= market["1"] %></span>
                                  <span><%= market["No goal"] %></span>
                                  <span><%= market["2"] %></span>
                                </div>
                              <% end %>
                            <% else %>
                              <div class="flex justify-around">
                                <span>-</span>
                                <span>-</span>
                                <span>-</span>
                              </div>
                            <% end %>
                          </td>
                          <td class="p-2 text-center">
                            <%= if odds_data = @odds[event.event_id] do %>
                              <%= with market <- get_market_odds(odds_data, "31", %{"Over" => "-", "Under" => "-"}) do %>
                                <div class="flex justify-around">
                                  <span><%= market["Over"] %></span>
                                  <span><%= market["Under"] %></span>
                                </div>
                              <% end %>
                            <% else %>
                              <div class="flex justify-around">
                                <span>-</span>
                                <span>-</span>
                              </div>
                            <% end %>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
