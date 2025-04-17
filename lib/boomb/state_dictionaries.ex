defmodule Boomb.StateDictionaries do

    def get_soccer_state_name(state) do

    dictionary = [%{"code"=>11000,"name"=>"Home Team Dangerous Attack"},%{"code"=>21000,"name"=>"Away Team Dangerous Attack"},%{"code"=>11001,"name"=>"Home Team Attack"},%{"code"=>21001,"name"=>"Away Team Attack"},%{"code"=>11002,"name"=>"Home Team In possession"},%{"code"=>21002,"name"=>"Away Team In possession"},%{"code"=>11004,"name"=>"Home Team Corner"},%{"code"=>21004,"name"=>"Away Team Corner"},%{"code"=>11007,"name"=>"Home Team Goal kick"},%{"code"=>21007,"name"=>"Away Team Goal kick"},%{"code"=>11008,"name"=>"Home Team Penalty"},%{"code"=>21008,"name"=>"Away Team Penalty"},%{"code"=>11009,"name"=>"Home Team Direct free kick"},%{"code"=>21009,"name"=>"Away Team Direct free kick"},%{"code"=>11010,"name"=>"Home Team Simple free kick"},%{"code"=>21010,"name"=>"Away Team Simple free kick"},%{"code"=>11024,"name"=>"Home Throw"},%{"code"=>21024,"name"=>"Away Throw"},%{"code"=>10008,"name"=>"Home Team Penalty Score"},%{"code"=>20008,"name"=>"Away Team Penalty Score"},%{"code"=>10009,"name"=>"Home Team Penalty Miss"},%{"code"=>20009,"name"=>"Away Team Penalty Miss"},%{"code"=>10021,"name"=>"Home Team Penalty To Take"},%{"code"=>20021,"name"=>"Away Team Penalty To Take"},%{"code"=>11003,"name"=>"Home Team Goal"},%{"code"=>21003,"name"=>"Away Team Goal"},%{"code"=>11005,"name"=>"Home Team Yellow Card"},%{"code"=>21005,"name"=>"Away Team Yellow Card"},%{"code"=>11006,"name"=>"Home Team Red Card"},%{"code"=>21006,"name"=>"Away Team Red Card"},%{"code"=>11011,"name"=>"Home Team Shot on goal"},%{"code"=>21011,"name"=>"Away Team Shot on goal"},%{"code"=>11012,"name"=>"Home Team Shot off goal"},%{"code"=>21012,"name"=>"Away Team Shot off goal"},%{"code"=>11013,"name"=>"Home Team Substitution"},%{"code"=>21013,"name"=>"Away Team Substitution"},%{"code"=>1014,"name"=>"Event Kick Off"},%{"code"=>1015,"name"=>"Half Time"},%{"code"=>1016,"name"=>"2nd Half"},%{"code"=>1017,"name"=>"Full Time"},%{"code"=>1018,"name"=>"Over Time - Kick Off"},%{"code"=>1019,"name"=>"Over Time - Half Time"},%{"code"=>1020,"name"=>"Over Time - 2nd Half"},%{"code"=>1021,"name"=>"Over Time - Full Time"},%{"code"=>1022,"name"=>"Penalty Shoot Out"},%{"code"=>1233,"name"=>"Match Info"},%{"code"=>1023,"name"=>"Penalty missed"},%{"code"=>11023,"name"=>"Home Team Penalty missed"},%{"code"=>21023,"name"=>"Away Team Penalty missed"},%{"code"=>1025,"name"=>"Injury"},%{"code"=>11025,"name"=>"Home Team Injury"},%{"code"=>21025,"name"=>"Away Team Injury"},%{"code"=>1237,"name"=>"Zoned Throw"},%{"code"=>11237,"name"=>"Home Team Zoned Throw"},%{"code"=>21237,"name"=>"Away Team Zoned Throw"},%{"code"=>1234,"name"=>"Offside"},%{"code"=>11234,"name"=>"Home Team Offside"},%{"code"=>21234,"name"=>"Away Team Offside"},%{"code"=>1238,"name"=>"Substitution"},%{"code"=>11238,"name"=>"Home Team Substitution"},%{"code"=>21238,"name"=>"Away Team Substitution"},%{"code"=>1332,"name"=>"VAR - Reviewing Goal"},%{"code"=>11332,"name"=>"Home Team VAR - Reviewing Goal"},%{"code"=>21332,"name"=>"Away Team VAR - Reviewing Goal"},%{"code"=>1331,"name"=>"VAR - Reviewing Red Card"},%{"code"=>11331,"name"=>"Home Team VAR - Reviewing Red Card"},%{"code"=>21331,"name"=>"Away Team VAR - Reviewing Red Card"},%{"code"=>1333,"name"=>"VAR - Reviewing Penalty"},%{"code"=>11333,"name"=>"Home Team VAR - Reviewing Penalty"},%{"code"=>21333,"name"=>"Away Team VAR - Reviewing Penalty"},%{"code"=>1330,"name"=>"VAR - In Progress"},%{"code"=>11330,"name"=>"Home Team VAR - In Progress"},%{"code"=>21330,"name"=>"Away Team VAR - In Progress"},%{"code"=>11901,"name"=>"Home Team Corner - Top"},%{"code"=>11902,"name"=>"Home Team Corner - Bottom"},%{"code"=>21901,"name"=>"Away Team Corner - Top"},%{"code"=>21902,"name"=>"Away Team Corner - Bottom"},%{"code"=>11931,"name"=>"Home Team Freekick - Pos. 1"},%{"code"=>11933,"name"=>"Home Team Freekick - Pos. 2"},%{"code"=>11935,"name"=>"Home Team Freekick - Pos. 3"},%{"code"=>11932,"name"=>"Home Team Freekick - Pos. 4"},%{"code"=>11934,"name"=>"Home Team Freekick - Pos. 5"},%{"code"=>11936,"name"=>"Home Team Freekick - Pos. 6"},%{"code"=>21931,"name"=>"Away Team Freekick - Pos. 7"},%{"code"=>21933,"name"=>"Away Team Freekick - Pos. 8"},%{"code"=>21935,"name"=>"Away Team Freekick - Pos. 9"},%{"code"=>21932,"name"=>"Away Team Freekick - Pos. 10"},%{"code"=>21934,"name"=>"Away Team Freekick - Pos. 11"},%{"code"=>21936,"name"=>"Away Team Freekick - Pos. 12"},%{"code"=>11301,"name"=>"Home TakeOnAttack"},%{"code"=>21300,"name"=>"Away TakeOnDangerousAttack"},%{"code"=>11302,"name"=>"Home TakeOnSafePossession"},%{"code"=>1026,"name"=>"InjuryTime"},%{"code"=>1004,"name"=>"Corner"},%{"code"=>21301,"name"=>"Away TakeOnAttack"},%{"code"=>21016,"name"=>"Away Secondhalf"},%{"code"=>11300,"name"=>"Home TakeOnDangerousAttack"},%{"code"=>1000,"name"=>"Danger"},%{"code"=>21026,"name"=>"Away InjuryTime"},%{"code"=>11016,"name"=>"Home Secondhalf"},%{"code"=>21302,"name"=>"Away TakeOnSafePossession"},%{"code"=>21014,"name"=>"Away Kickoff"},%{"code"=>11014,"name"=>"Home Kickoff"},%{"code"=>1005,"name"=>"YellowCard"},%{"code"=>21022,"name"=>"Away Penaltyshootout"},%{"code"=>11022,"name"=>"Home Penaltyshootout"},%{"code"=>1009,"name"=>"Dfreekick"},%{"code"=>1003,"name"=>"Goal"},%{"code"=>11026,"name"=>"Home InjuryTime"}]
    event = Enum.filter(dictionary, fn x -> x["code"] == String.to_integer(state) end) #state
    #IO.puts "------------------state---#{inspect state}-----#{inspect event}----------------"
        name = if event != [] do
            event
                |>List.first()
                |>get_in([Access.key("name")])
        else
            "-"
        end
    end

    def get_basket_state_name(state) do

    dictionary = [%{"code"=>11074,"name"=>"Home Team Score 2 points"},%{"code"=>21074,"name"=>"Away Team Score 2 points"},%{"code"=>11075,"name"=>"Home Team Score 3 points"},%{"code"=>21075,"name"=>"Away Team Score 3 points"},%{"code"=>11077,"name"=>"Home Team in Possession"},%{"code"=>21077,"name"=>"Away Team in Possession"},%{"code"=>11078,"name"=>"Home Team Free Throw"},%{"code"=>21078,"name"=>"Away Team Free Throw"},%{"code"=>11079,"name"=>"Home Team Free Throw Scored"},%{"code"=>21079,"name"=>"Away Team Free Throw Scored"},%{"code"=>11080,"name"=>"Home Team Free Throw Missed"},%{"code"=>21080,"name"=>"Away Team Free Throw Missed"},%{"code"=>11081,"name"=>"Home Team Timeout"},%{"code"=>21081,"name"=>"Away Team Timeout"},%{"code"=>11086,"name"=>"Home Team Foul"},%{"code"=>21086,"name"=>"Away Team Foul"},%{"code"=>1082,"name"=>"End Of Quarter"},%{"code"=>1083,"name"=>"End Of Half"},%{"code"=>1084,"name"=>"End Of Match"},%{"code"=>1085,"name"=>"Over Time"},%{"code"=>1087,"name"=>"Quarter 1"},%{"code"=>1088,"name"=>"Quarter 2"},%{"code"=>1089,"name"=>"Quarter 3"},%{"code"=>1090,"name"=>"Quarter 4"},%{"code"=>1091,"name"=>"1st Half"},%{"code"=>1092,"name"=>"2nd Half"}]
    event = Enum.filter(dictionary, fn x -> x["code"] == state end) #state
        name = if event != [] do
            event
                |>List.first()
                |>get_in([Access.key("name")])
        else
            "-"
        end
    end

    def get_tennis_state_name(state) do

    dictionary = [%{"code"=>11113,"name"=>"Player 1 Serve"},%{"code"=>21113,"name"=>"Player 2 Serve"},%{"code"=>11114,"name"=>"Player 1 Score Point"},%{"code"=>21114,"name"=>"Player 2 Score Point"},%{"code"=>11115,"name"=>"Player 1 Score Point"},%{"code"=>21115,"name"=>"Player 2 Score Point"},%{"code"=>11116,"name"=>"Player 1 Double Fault"},%{"code"=>21116,"name"=>"Player 2 Double Fault"},%{"code"=>11117,"name"=>"Player 1 Ace"},%{"code"=>21117,"name"=>"Player 2 Ace"},%{"code"=>11118,"name"=>"Player 1 Break point"},%{"code"=>21118,"name"=>"Player 2 Break point"},%{"code"=>11119,"name"=>"Player 1 Win a Game"},%{"code"=>21119,"name"=>"Player 2 Win a Game"},%{"code"=>11120,"name"=>"Player 1 Statistic"},%{"code"=>21120,"name"=>"Player 2 Statistic"},%{"code"=>11121,"name"=>"Player 1 let 1st Serve"},%{"code"=>21121,"name"=>"Player 2 let 1st Serve"},%{"code"=>11122,"name"=>"Player 1 let 2nd Serve"},%{"code"=>21122,"name"=>"Player 2 let 2nd Serve"},%{"code"=>1123,"name"=>"Game Set Match"},%{"code"=>11123,"name"=>"Player 1 Game Set Match"},%{"code"=>21123,"name"=>"Player 2 Game Set Match"},%{"code"=>1124,"name"=>"End of Set"},%{"code"=>11124,"name"=>"Player 1 End of Set"},%{"code"=>21124,"name"=>"Player 2 End of Set"},%{"code"=>11125,"name"=>"Player 1 Score a Point in Tie Break"},%{"code"=>21125,"name"=>"Player 2 Score a Point in Tie Break"},%{"code"=>11126,"name"=>"Player 1 Injury Break"},%{"code"=>21126,"name"=>"Player 2 Injury Break"},%{"code"=>11128,"name"=>"Player 1 Point Score"},%{"code"=>21128,"name"=>"Player 2 Point Score"},%{"code"=>11129,"name"=>"Player 1 Challenge Success"},%{"code"=>21129,"name"=>"Player 2 Challenge Success"},%{"code"=>11130,"name"=>"Player 1 Challenge Failed"},%{"code"=>21130,"name"=>"Player 2 Challenge Failed"},%{"code"=>1127,"name"=>"Rain Delay"},%{"code"=>1134,"name"=>"1st Set"},%{"code"=>1135,"name"=>"2nd Set"},%{"code"=>1136,"name"=>"3rd Set"},%{"code"=>1137,"name"=>"4th Set"},%{"code"=>1138,"name"=>"Final Set"}]
    event = Enum.filter(dictionary, fn x -> x["code"] == state end) #state
        name = if event != [] do
            event
                |>List.first()
                |>get_in([Access.key("name")])
        else
            "-"
        end
    end

    def get_baseball_state_name(state) do

    dictionary = []
    event = Enum.filter(dictionary, fn x -> x["code"] == state end) #state
        name = if event != [] do
            event
                |>List.first()
                |>get_in([Access.key("name")])
        else
            "-"
        end
    end

    def get_amfooball_state_name(state) do

    dictionary = []
    event = Enum.filter(dictionary, fn x -> x["code"] == state end) #state
        name = if event != [] do
            event
                |>List.first()
                |>get_in([Access.key("name")])
        else
            "-"
        end
    end
    def get_hockey_state_name(state) do

    dictionary = [%{"code"=>11270,"name"=>"Home Team On Possession"},%{"code"=>21270,"name"=>"Away Team On Possession"},%{"code"=>11271,"name"=>"Home Team Penalty"},%{"code"=>21271,"name"=>"Away Team Penalty"},%{"code"=>11272,"name"=>"Home Team Power Play Over"},%{"code"=>21272,"name"=>"Away Team Power Play Over"},%{"code"=>11273,"name"=>"Home Team Shot"},%{"code"=>21273,"name"=>"Away Team Shot"},%{"code"=>11274,"name"=>"Home Team Goal"},%{"code"=>21274,"name"=>"Away Team Goal"},%{"code"=>11275,"name"=>"Home Team Penalty Shot"},%{"code"=>21275,"name"=>"Away Team Penalty Shot"},%{"code"=>11276,"name"=>"Home Team Penalty Shot Missed"},%{"code"=>21276,"name"=>"Away Team Penalty Shot Missed"},%{"code"=>11277,"name"=>"Home Team Pulled Keeper"},%{"code"=>21277,"name"=>"Away Team Pulled Keeper"},%{"code"=>11278,"name"=>"Home Team Keeper Back In Goal"},%{"code"=>21278,"name"=>"Away Team Keeper Back In Goal"},%{"code"=>1281,"name"=>"Overtime Start"},%{"code"=>1282,"name"=>"Overtime End"},%{"code"=>1283,"name"=>"Penalty Shootout"},%{"code"=>11284,"name"=>"Home Team Face Off"},%{"code"=>21284,"name"=>"Away Team Face Off"},%{"code"=>11285,"name"=>"Home Team Puck Dropped"},%{"code"=>21285,"name"=>"Away Team Puck Dropped"},%{"code"=>11286,"name"=>"Home Team Face Off Winner"},%{"code"=>21286,"name"=>"Away Team Face Off Winner"},%{"code"=>11287,"name"=>"Home Team Timeout"},%{"code"=>21287,"name"=>"Away Team Timeout"},%{"code"=>11288,"name"=>"Home Team Icing"},%{"code"=>21288,"name"=>"Away Team Icing"},%{"code"=>11289,"name"=>"Home Team Power Play"},%{"code"=>21289,"name"=>"Away Team Power Play"}]
    event = Enum.filter(dictionary, fn x -> x["code"] == state end) #state
        name = if event != [] do
            event
                |>List.first()
                |>get_in([Access.key("name")])
        else
            "-"
        end
    end

    def get_volleyball_state_name(state) do

    dictionary = [%{"code"=>11248,"name"=>"Home Team Single Serve"},%{"code"=>21248,"name"=>"Away Team Single Serve"},%{"code"=>11249,"name"=>"Home Team Singles Serve (Rally)"},%{"code"=>21249,"name"=>"Away Team Singles Serve (Rally)"},%{"code"=>11250,"name"=>"Home Team Singles Serve (PointScore)"},%{"code"=>21250,"name"=>"Away Team Singles Serve (PointScore)"},%{"code"=>11252,"name"=>"Home Team Service fault"},%{"code"=>21252,"name"=>"Away Team Service fault"},%{"code"=>11253,"name"=>"Home Team Ace"},%{"code"=>21253,"name"=>"Away Team Ace"},%{"code"=>11254,"name"=>"Home Team Single Serve (End Of Set)"},%{"code"=>21254,"name"=>"Away Team Single Serve (End Of Set)"},%{"code"=>11255,"name"=>"Home Team Timeout"},%{"code"=>21255,"name"=>"Away Team Timeout"},%{"code"=>11256,"name"=>"Home Team Timeout"},%{"code"=>21256,"name"=>"Away Team Timeout"},%{"code"=>11257,"name"=>"Home Team Last Six"},%{"code"=>21257,"name"=>"Home Team Last Six"},%{"code"=>11258,"name"=>"Home Team Score Breakdown"},%{"code"=>21258,"name"=>"Away Team Score Breakdown"},%{"code"=>11259,"name"=>"Home Team Current Streak"},%{"code"=>21259,"name"=>"Away Team Current Streak"},%{"code"=>11260,"name"=>"Home Team Single Serve (Point Score)"},%{"code"=>21260,"name"=>"Away Team Single Serve (Point Score)"},%{"code"=>1261,"name"=>"Finished"}]
    event = Enum.filter(dictionary, fn x -> x["code"] == state end) #state
        name = if event != [] do
            event
                |>List.first()
                |>get_in([Access.key("name")])
        else
            "-"
        end
    end
end
