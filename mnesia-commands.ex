
debug] Unrecognized odds format: %{"ismain" => "False", "name" => "3.5", "odds" => [%{"name" => "Over", "stop" => "False", "value" => "6.50"}, %{"name" => "Under", "stop" => "False", "value" => "1.10"}], "stop" => "False", "type" => "total"}

[:pregame_darts, :pregame_tennis, :pregame_mma, :pregame_rugby,
 :pregame_football, :pregame_boxing, :pregame_golf, :pregame_volleyball,
 :pregame_futsal, :pregame_handball, :pregame_rugbyleague, :pregame_esports,
 :event, :pregame_table_tennis, :schema, :pregame_hockey, :pregame_soccer,
 :pregame_baseball, :pregame_cricket, :pregame_basketball]
:mnesia.transaction(fn ->
  match = {
    :pregame_soccer,
    "7890000",
    1_745_240_400, # 2025-04-20 14:00:00 UTC
    "Chelsea",
    "Arsenal",
    "England",
    "Premier League",
    %{moneyline: %{odd1: 2.50, odd2: 2.80, draw: 3.10}, total: %{value: 2.5, over: 1.90, under: 1.90}},
    %{},
    1_745_200_000
  }
  :mnesia.write(:pregame_soccer, match, :write)
end)

:mnesia.transaction(fn ->:mnesia.select(:pregame_soccer, [{{:pregame_soccer, :"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8", :"$9"},[{:!=, :"$1", ""}],[:"$$"]}])end)



:mnesia.transaction(fn -> :mnesia.select(:pregame_soccer, [ {{:pregame_soccer, :$1, :$2, :$3, :$4, :$5, :$6, :$7, :$8, :$9}, [{:!=, :$1, ""}], [:"$$"]} ]) end)
:mnesia.select(Odd, [{{Odd, :"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8"}, [{:==, :"$2", id}], [:"$$"]}])


:mnesia.transaction(fn ->
  :mnesia.index_match_object(:pregame_soccer, { :pregame_soccer, "123456", :_, :_, :_, :_, :_, :_, :_ }, :league, :read)
end)
{:atomic, []}

:mnesia.transaction(fn -> :mnesia.read({:pregame_soccer, "123456"}) end)






[:pregame_soccer, [{{:pregame_soccer, :_, :"$1", :_, :_, :"$2", :"$3", :_, :_, :_}, [{:>=, :"$1", 1745098985}, {:<=, :"$1", 1745107199}], [{{:"$2", :"$3"}}]}]]}
:mnesia.transaction(fn -> :mnesia.select(:pregame_soccer, [ {{:pregame_soccer, :"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8", :"$9"}, [{:>, :"$2", 1745098985}, {:<, :"$2", 1745107199}], [:"$$"]} ]) end)
:mnesia.transaction(fn -> :mnesia.select(:pregame_soccer, [ {{:pregame_soccer, :"$1", :_, :_, :_, :_, :_, :_, :_, :_}, [], [:"$1"]} ]) end)
"5762948", "5762949"







# with results

:mnesia.table_info(:pregame_soccer, :attributes)
[:match_id, :sport, :country, :league, :start_time, :teams, :odds, :metadata, :timestamp]

[:match_id, :start_time, :team1_name, :team2_name, :country, :league, :markets, :stats, :updated_at]
:mnesia.system_info(:tables)
[:pregame_darts, :pregame_tennis, :pregame_mma, :pregame_rugby,
 :pregame_football, :pregame_boxing, :pregame_golf, :pregame_volleyball,
 :pregame_futsal, :pregame_handball, :pregame_rugbyleague, :pregame_esports,
 :event, :pregame_table_tennis, :schema, :pregame_hockey, :pregame_soccer,
 :pregame_baseball, :pregame_cricket, :pregame_basketball]

:mnesia.transaction(fn -> :mnesia.select(:pregame_soccer, [ {{:pregame_soccer, :"$1", :_, :_, :_, :_, :_, :_, :_, :_}, [], [:"$1"]} ]) end)
{:atomic, ["123456", "7890000"]}

:mnesia.transaction(fn -> :mnesia.select(:pregame_soccer, [ {{:pregame_basketball, :"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8", :"$9"}, [{:==, :"$1", "123456"}], [:"$$"]} ]) end)
iex(39)> :mnesia.transaction(fn -> :mnesia.select(:pregame_soccer, [ {{:pregame_soccer, :"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8", :"$9"}, [{:==, :"$1", "123456"}], [:"$$"]} ]) end)
{:atomic,
 [
   [
     "123456",
     1745232000,
     "Manchester United",
     "Liverpool",
     "England",
     "Premier League",
     %{
       moneyline: %{odd1: 2.1, odd2: 3.2, draw: 3.0},
       spread: %{value: -0.5, odd1: 1.95, odd2: 1.85}
     },
     %{},
     1745200000
   ]
 ]}

 :mnesia.transaction(fn -> :mnesia.read({:pregame_soccer, "123456"}) end)
{:atomic,
 [
   {:pregame_soccer, "123456", 1745232000, "Manchester United", "Liverpool",
    "England", "Premier League",
    %{
      moneyline: %{odd1: 2.1, odd2: 3.2, draw: 3.0},
      spread: %{value: -0.5, odd1: 1.95, odd2: 1.85}
    }, %{}, 1745200000}
 ]}

 :mnesia.transaction(fn ->
  :mnesia.index_match_object(:pregame_soccer, { :pregame_soccer, :_, :_, :_, :_, :_, "Premier League", :_, :_, :_ }, :league, :read)
end)
{:atomic,
 [
   {:pregame_soccer, "7890000", 1745240400, "Chelsea", "Arsenal", "England",
    "Premier League",
    %{
      total: %{value: 2.5, over: 1.9, under: 1.9},
      moneyline: %{odd1: 2.5, odd2: 2.8, draw: 3.1}
    }, %{}, 1745200000},
   {:pregame_soccer, "123456", 1745232000, "Manchester United", "Liverpool",
    "England", "Premier League",
    %{
      moneyline: %{odd1: 2.1, odd2: 3.2, draw: 3.0},
      spread: %{value: -0.5, odd1: 1.95, odd2: 1.85}
    }, %{}, 1745200000}
 ]}
{:atomic,
 [
   {:pregame_soccer, "7890000", 1745240400, "Chelsea", "Arsenal", "England",
    "Premier League",
    %{
      total: %{value: 2.5, over: 1.9, under: 1.9},
      moneyline: %{odd1: 2.5, odd2: 2.8, draw: 3.1}
    }, %{}, 1745200000},
   {:pregame_soccer, "123456", 1745232000, "Manchester United", "Liverpool",
    "England", "Premier League",
    %{
      moneyline: %{odd1: 2.1, odd2: 3.2, draw: 3.0},
      spread: %{value: -0.5, odd1: 1.95, odd2: 1.85}
    }, %{}, 1745200000}
 ]}

 :mnesia.transaction(fn ->
  :mnesia.index_match_object(:pregame_soccer, { :pregame_soccer, :_, 1_745_232_000, :_, :_, :_, :_, :_, :_, :_ }, :start_time, :read)
end)
 {:atomic,
 [
   {:pregame_soccer, "123456", 1745232000, "Manchester United", "Liverpool",
    "England", "Premier League",
    %{
      moneyline: %{odd1: 2.1, odd2: 3.2, draw: 3.0},
      spread: %{value: -0.5, odd1: 1.95, odd2: 1.85}
    }, %{}, 1745200000}
 ]}

 :mnesia.transaction(fn ->
  :mnesia.match_object(:pregame_soccer, { :pregame_soccer, :_, :_, :_, :_, :_, :_, :_, :_, :_ }, :read)
end)
 {:atomic,
 [
   {:pregame_soccer, "123456", 1745232000, "Manchester United", "Liverpool",
    "England", "Premier League",
    %{
      moneyline: %{odd1: 2.1, odd2: 3.2, draw: 3.0},
      spread: %{value: -0.5, odd1: 1.95, odd2: 1.85}
    }, %{}, 1745200000},
   {:pregame_soccer, "7890000", 1745240400, "Chelsea", "Arsenal", "England",
    "Premier League",
    %{
      total: %{value: 2.5, over: 1.9, under: 1.9},
      moneyline: %{odd1: 2.5, odd2: 2.8, draw: 3.1}
    }, %{}, 1745200000}
 ]}


 iex(63)> :mnesia.table_info(:pregame_soccer, :all)
[
  {:access_mode, :read_write},
  {:active_replicas, [:nonode@nohost]},
  {:all_nodes, [:nonode@nohost]},
  {:arity, 10},
  {:attributes,
   [:match_id, :start_time, :team1_name, :team2_name, :country, :league,
    :markets, :stats, :updated_at]},
  {:checkpoints, []},
  {:commit_work,
   [
     {:index, :ordered_set,
      [
        {{7, :ordered}, {:ram, #Reference<0.2593835490.3360030721.151970>}},
        {{3, :ordered}, {:ram, #Reference<0.2593835490.3360030721.151962>}}
      ]}
   ]},
  {:cookie, {{1745038026642903875, -576460752303416478, 1}, :nonode@nohost}},
  {:cstruct,
   {:cstruct, :pregame_soccer, :ordered_set, [], [:nonode@nohost], [], [], 0,
    :read_write, false, [{3, :ordered}, {7, :ordered}], [], false,
    :pregame_soccer,
    [:match_id, :start_time, :team1_name, :team2_name, :country, :league,
     :markets, :stats, :updated_at], [], [], [],
    {{1745038026642903875, -576460752303416478, 1}, :nonode@nohost},
    {{2, 0}, []}}},

 {:disc_copies, [:nonode@nohost]},
  {:disc_only_copies, []},
  {:external_copies, []},
  {:frag_properties, []},
  {:index, [7, 3]},
  {:index_info,
   {:index, :ordered_set,
    [
      {{7, :ordered}, {:ram, #Reference<0.2593835490.3360030721.151970>}},
      {{3, :ordered}, {:ram, #Reference<0.2593835490.3360030721.151962>}}
    ]}},
  {:load_by_force, false},
  {:load_node, :nonode@nohost},
  {:load_order, 0},
  {:load_reason, :local_only},
  {:local_content, false},
  {:majority, false},
  {:master_nodes, []},
  {:memory, 337},
  {:ram_copies, []},
  {:record_name, :pregame_soccer},
  {:record_validation, {:pregame_soccer, 10, :ordered_set}},
  {:size, 2},
  {:snmp, []},
  {:storage_properties, []},
  {:storage_type, :disc_copies},
  {:subscribers, []},
  {:type, :ordered_set},
  {:user_properties, []},
  {:version, {{2, 0}, []}},
  {:where_to_commit, [nonode@nohost: :disc_copies]},
  {:where_to_read, :nonode@nohost},
  {:where_to_wlock, {[:nonode@nohost], false}},
  {:where_to_write, [:nonode@nohost]},
  {:wild_pattern, {:pregame_soccer, :_, :_, :_, :_, :_, :_, :_, :_, ...}},
  {{:index, 3}, #Reference<0.2593835490.3360030721.151962>},
  {{:index, 7}, #Reference<0.2593835490.3360030721.151970>}
    ]
