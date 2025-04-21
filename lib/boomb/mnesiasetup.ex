defmodule Boomb.MnesiaSetup do
  def init do
    :mnesia.create_schema([node()])
    :mnesia.start()
    IO.puts ";;;;;;;;;;;;;;;;;;;;;;;;;;"
    IO.inspect :mnesia.create_table(:soccer_pregame,
      attributes: [:id, :sport, :country, :league, :starttime, :home_team, :away_team, :odds],
      disc_copies: [node()]
    )
    IO.puts ";;;;;;;;;;;;;;;;;;;;;;;;;;"
    IO.inspect :mnesia.create_table(:basket_pregame,
      attributes: [:id, :sport, :country, :league, :starttime, :home_team, :away_team, :odds],
      disc_copies: [node()]
    )
    IO.puts ";;;;;;;;;;;;;;;;;;;;;;;;;;"
    IO.inspect :mnesia.create_table(:tennis_pregame,
      attributes: [:id, :sport, :country, :league, :starttime, :home_team, :away_team, :odds],
      disc_copies: [node()]
    )
  end
end
