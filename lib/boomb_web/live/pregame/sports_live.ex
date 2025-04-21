defmodule BoombWeb.Pregame.SportsLive do
  use BoombWeb, :live_view
  require Logger

  @sports [
    :soccer, :basketball, :tennis, :hockey, :handball, :volleyball, :football,
    :baseball, :cricket, :rugby, :rugbyleague, :boxing, :esports, :futsal,
    :mma, :table_tennis, :golf, :darts
  ]
  @filters [
    :one_hour, :three_hours, :six_hours, :twelve_hours, :today, :all
  ]

  def mount(params, _session, socket) do
    sport = String.to_atom(params["sport"] || "soccer")
    filter = String.to_atom(params["filter"] || "today")
    selected_sport = if sport in @sports, do: sport, else: :soccer
    selected_filter = if filter in @filters, do: filter, else: :today

    socket =
      socket
      |> assign(:sports, @sports)
      |> assign(:filters, @filters)
      |> assign(:selected_sport, selected_sport)
      |> assign(:filter, selected_filter)
      |> assign(:selected_leagues, %{})
      |> assign(:leagues, fetch_leagues(selected_sport, selected_filter))

    {:ok, socket}
  end

  def handle_event("select_sport", %{"sport" => sport}, socket) do
    sport_atom = String.to_atom(sport)
    sport_atom = if sport_atom in @sports, do: sport_atom, else: :soccer
    socket =
      socket
      |> assign(:selected_sport, sport_atom)
      |> assign(:selected_leagues, %{})
      |> assign(:leagues, fetch_leagues(sport_atom, socket.assigns.filter))
    {:noreply, socket}
  end

  def handle_event("select_filter", %{"filter" => filter}, socket) do
    filter_atom = String.to_atom(filter)
    filter_atom = if filter_atom in @filters, do: filter_atom, else: :today
    socket =
      socket
      |> assign(:filter, filter_atom)
      |> assign(:selected_leagues, %{})
      |> assign(:leagues, fetch_leagues(socket.assigns.selected_sport, filter_atom))
    {:noreply, socket}
  end

  def handle_event("toggle_league", %{"league" => league}, socket) do
    selected_leagues = socket.assigns.selected_leagues
    selected_leagues =
      if Map.has_key?(selected_leagues, league) do
        Map.delete(selected_leagues, league)
      else
        Map.put(selected_leagues, league, true)
      end
    {:noreply, assign(socket, :selected_leagues, selected_leagues)}
  end

  def handle_event("select_all", _, socket) do
    selected_leagues =
      socket.assigns.leagues
      |> Enum.reduce(%{}, fn {country, league, _matches}, acc ->
        Map.put(acc, "#{country}:#{league}", true)
      end)
    {:noreply, assign(socket, :selected_leagues, selected_leagues)}
  end

  def handle_event("validate_selection", _, socket) do
    selected_leagues = Map.keys(socket.assigns.selected_leagues)
    if selected_leagues == [] do
      {:noreply, socket}
    else
      params = [sport: socket.assigns.selected_sport, filter: socket.assigns.filter, leagues: selected_leagues]
      Logger.debug("Navigating to matches with params: #{inspect(params)}")
      url = ~p"/pregame/matches?#{params}"
      Logger.debug("Generated navigation URL: #{url}")
      {:noreply, push_navigate(socket, to: url)}
    end
  end

  def fetch_leagues(sport, filter) do
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
                    {:ok, end_of_day} -> DateTime.to_unix(end_of_day, :second) + 60
                    _ -> now + 24 * 3600
                  end
                _ -> now + 24 * 3600
              end
            _ -> now + 24 * 3600
          end
        :all -> now + 365 * 24 * 3600 + 60
      end

    try do
      :mnesia.transaction(fn ->
        :mnesia.select(table, [
          {{table, :_, :"$1", :_, :_, :"$2", :"$3", :_, :_, :_},
           [{:>, :"$1", now}, {:<, :"$1", filter_time}],
           [{{:"$2", :"$3"}}]}
        ])
      end)
      |> case do
        {:atomic, results} ->
          results
          |> Enum.uniq()
          |> Enum.group_by(fn {country, _league} -> normalize_country(country) end, fn {_country, league} -> normalize_league_name(league) end)
          |> Enum.map(fn {country, leagues} ->
            {country, Enum.sort(leagues), length(leagues)}
          end)
          |> Enum.sort_by(fn {country, _, _} -> country end)
        {:aborted, reason} ->
          Logger.error("Mnesia select failed for #{table}: #{inspect(reason)}")
          []
      end
    catch
      :exit, reason ->
        Logger.error("Mnesia table_info failed for #{table}: #{inspect(reason)}")
        []
    end
  end

  defp filter_label(filter) do
    case filter do
      :one_hour -> "1 Hour"
      :three_hours -> "3 Hours"
      :six_hours -> "6 Hours"
      :twelve_hours -> "12 Hours"
      :today -> "Today"
      :all -> "All"
      _ -> "Unknown"
    end
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
