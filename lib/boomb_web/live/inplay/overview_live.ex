defmodule BoombWeb.OverviewLive do
  use BoombWeb, :live_view
  require Logger

  @sports ["soccer", "basket", "tennis", "baseball", "amfootball", "hockey", "volleyball"]
  @sport_icons %{
    "soccer" => "⚽",
    "basket" => "🏀",
    "tennis" => "🎾",
    "baseball" => "⚾",
    "amfootball" => "🏈",
    "hockey" => "🏒",
    "volleyball" => "🏐"
  }

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Enum.each(@sports, fn sport ->
        Phoenix.PubSub.subscribe(Boomb.PubSub, "events_available:#{sport}")
      end)
    end

    sports_data = Boomb.SportsCache.get_sports()
    events_by_competition = organize_events_by_competition(sports_data, nil)
    odds = Boomb.OddsCache.get_all_odds()

    socket =
      socket
      |> assign(:selected_sport, nil)
      |> assign(:sports, @sports)
      |> assign(:odds, odds)
      |> assign(:events_by_competition, events_by_competition)
      |> assign(:subscribed_event_ids, MapSet.new())

    update_event_subscriptions(socket, events_by_competition)
    {:ok, socket}
  end

  @impl true
  def handle_event("filter_by_sport", %{"sport" => sport}, socket) do
    selected_sport = if sport == "all" or sport == socket.assigns.selected_sport, do: nil, else: sport
    sports_data = Boomb.SportsCache.get_sports()
    events_by_competition = organize_events_by_competition(sports_data, selected_sport)

    socket =
      socket
      |> assign(:selected_sport, selected_sport)
      |> assign(:events_by_competition, events_by_competition)

    update_event_subscriptions(socket, events_by_competition)
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{events: events}, socket) when is_list(events) do
    valid_events = Enum.filter(events, &valid_event?/1)
    if length(events) != length(valid_events) do
      Logger.warning("Invalid events filtered: #{inspect(Enum.reject(events, &valid_event?/1))}")
    end

    Enum.each(valid_events, fn event ->
      Boomb.Event.upsert(event)
    end)
    Boomb.SportsCache.update_sports(Boomb.Event.group_by_sport())

    sports_data = Boomb.SportsCache.get_sports()
    events_by_competition = organize_events_by_competition(sports_data, socket.assigns.selected_sport)

    socket =
      socket
      |> assign(:events_by_competition, events_by_competition)

    update_event_subscriptions(socket, events_by_competition)
    {:noreply, socket}
  end

  def handle_info(%{event_id: event_id, odds: odds, score: score, period_time: period_time}, socket) do
    updated_odds = Map.put(socket.assigns.odds, event_id, %{
      odds: odds,
      score: score,
      period_time: period_time
    })

    {:noreply, assign(socket, :odds, updated_odds)}
  end

  def handle_info(msg, socket) do
    Logger.warning("Unhandled message in OverviewLive: #{inspect(msg)}")
    {:noreply, socket}
  end

  defp organize_events_by_competition(sports_data, selected_sport) do
    filtered_data = if selected_sport do
      Map.take(sports_data, [selected_sport])
    else
      sports_data
    end

    filtered_data
    |> Enum.flat_map(fn {sport, events} ->
      valid_events = Enum.filter(events, &valid_event?/1)
      if length(events) != length(valid_events) do
        Logger.warning("Invalid events in #{sport}: #{inspect(Enum.reject(events, &valid_event?/1))}")
      end
      valid_events
      |> Enum.group_by(& &1.competition_name)
      |> Enum.map(fn {comp_name, comp_events} -> {sport, comp_name, comp_events} end)
    end)
    |> Enum.sort_by(fn {sport, comp_name, _} -> {sport, comp_name} end)
  end

  defp valid_event?(event) do
    is_map(event) and
      Map.has_key?(event, :event_id) and
      Map.has_key?(event, :sport) and
      Map.has_key?(event, :competition_name) and
      Map.has_key?(event, :team1) and
      Map.has_key?(event, :team2)
  end

  defp update_event_subscriptions(socket, events_by_competition) do
    current_event_ids =
      events_by_competition
      |> Enum.flat_map(fn {_sport, _comp_name, events} -> Enum.map(events, & &1.event_id) end)
      |> MapSet.new()

    previous_event_ids = socket.assigns.subscribed_event_ids
    to_unsubscribe = MapSet.difference(previous_event_ids, current_event_ids)
    to_subscribe = MapSet.difference(current_event_ids, previous_event_ids)

    Enum.each(to_unsubscribe, fn event_id ->
      Enum.each(@sports, fn sport ->
        Phoenix.PubSub.unsubscribe(Boomb.PubSub, "odds_update:#{sport}:#{event_id}")
      end)
    end)

    Enum.each(to_subscribe, fn event_id ->
      Enum.each(@sports, fn sport ->
        Phoenix.PubSub.subscribe(Boomb.PubSub, "odds_update:#{sport}:#{event_id}")
      end)
    end)

    assign(socket, :subscribed_event_ids, current_event_ids)
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
    "#{minutes}'#{String.pad_leading(to_string(seconds), 2, "0")}\""
  end

  defp sport_count(sports_data, sport) do
    case Map.get(sports_data, sport) do
      nil -> 0
      events -> length(events)
    end
  end

  defp sport_icon(sport) do
    Map.get(@sport_icons, sport, "•")
  end
end