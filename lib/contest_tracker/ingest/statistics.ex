defmodule ContestTracker.Ingest.Statistics do
  @score_types %{
    "XPM" => 0,
    "XP" => 1,
    "TD" => 6,
    "2PPF" => 0,
    "2PRF" => 0,
    "2PR" => 2,
    "2PP" => 2,
    "FG" => 3
  }

  defp get_side(%{"posteam" => side}, home_abbr) when side == home_abbr, do: :home
  defp get_side(%{"posteam" => side}, home_abbr) when side != home_abbr, do: :away

  def convert_stat(yards, touchdowns \\ 0, passing \\ false) do
    %{yards: yards, touchdowns: touchdowns, dk_points: touchdowns * 6 + yards / 10}
  end

  def parse_stat(%{"statId" => 10, "yards" => yds}), do: %{rushing: %{yards: yds}}
  def parse_stat(%{"statId" => 11, "yards" => yds}), do: %{rushing: %{yards: yds, touchdowns: 1}}
  def parse_stat(%{"statId" => 12, "yards" => yds}), do: %{rushing: %{yards: yds}}
  def parse_stat(%{"statId" => 13, "yards" => yds}), do: %{rushing: %{yards: yds, touchdowns: 1}}
  def parse_stat(%{"statId" => 15, "yards" => yds}), do: %{passing: %{yards: yds}}
  def parse_stat(%{"statId" => 16, "yards" => yds}), do: %{passing: %{yards: yds, touchdowns: 1}}
  def parse_stat(%{"statId" => 17, "yards" => yds}), do: %{passing: %{yards: yds}}
  def parse_stat(%{"statId" => 18, "yards" => yds}), do: %{passing: %{touchdowns: 1}}
  def parse_stat(%{"statId" => 19, "yards" => yds}), do: %{passing: %{ints: 1}}
  def parse_stat(%{"statId" => 20}), do: %{passing: %{sacks: 1}}

  def parse_stat(%{"statId" => 21, "yards" => yds}) do
    %{receiving: %{receptions: 1, yards: yds}}
  end

  def parse_stat(%{"statId" => 22, "yards" => yds}) do
    %{receiving: %{receptions: 1, yards: yds, touchdowns: 1}}
  end

  def parse_stat(%{"statId" => 23, "yards" => yds}), do: %{receiving: %{yards: yds}}
  def parse_stat(%{"statId" => 24, "yards" => yds}), do: %{receiving: %{touchdowns: 1}}
  def parse_stat(%{"statId" => 70, "yards" => yds}) when yds < 40, do: %{kicking: %{fg_3: 1}}
  def parse_stat(%{"statId" => 70, "yards" => yds}) when yds < 50, do: %{kicking: %{fg_4: 1}}
  def parse_stat(%{"statId" => 70, "yards" => yds}) when yds >= 50, do: %{kicking: %{fg_5: 1}}
  def parse_stat(%{"statId" => 72}), do: %{kicking: %{xp: 1}}
  def parse_stat(_), do: nil

  def aggregate_stats(plays) do
    Enum.reduce(plays, %{}, fn play, acc ->
      Enum.reduce(play["players"], acc, fn {player, stats}, acc ->
        [%{"clubcode" => team, "playerName" => name} | _] = stats
        converted_stats = Enum.map(stats, &parse_stat/1)
        |> Enum.reject(&is_nil/1)

        if Enum.empty?(converted_stats) do
        	acc
        else
        	Map.update(acc, {player, name, team}, converted_stats, &(&1 ++ converted_stats))
        end
      end)
    end)
    |> Enum.map(fn {{player_id, name, team}, stats} ->
      Enum.reduce(stats, %{id: player_id, name: name, team: team}, fn stat, res ->
        Map.merge(res, stat, fn _, v1, v2 ->
          Map.merge(v1, v2, fn _, v3, v4 ->
            v3 + v4
          end)
        end)
      end)
    end)
  end

  def defense(team, stats, score) do
    %{id: "TEAM", name: team, team: team, defense: Map.put(stats, :points, score)}
  end

  def parse(game_id \\ "2020020200") do
    {:ok, %HTTPoison.Response{status_code: 200, body: body}} =
      HTTPoison.get("http://www.nfl.com/liveupdate/game-center/#{game_id}/#{game_id}_gtd.json")

    %{^game_id => updates} = Jason.decode!(body)

    %{
      "home" => %{"abbr" => home_abbr},
      "away" => %{"abbr" => away_abbr},
      "scrsummary" => scores,
      "drives" => drives
    } = updates

    drive_list = Enum.map(Map.delete(drives, "crntdrv"), fn {seq, drive} ->
      Map.put(drive, "sequence", seq)
    end)

    plays =
      Enum.map(drive_list, fn drive ->
        drive_info = Map.delete(drive, "plays")
        Enum.map(drive["plays"], fn {play_id, play} ->
          Map.merge(play, %{quarter: drive["qtr"], drive: drive_info, id: play_id})
        end)
      end)
      |> List.flatten
      |> Enum.sort_by(&String.to_integer(&1.id))

    scoring_plays = Enum.filter(plays, &Enum.member?(Map.keys(@score_types), &1["note"]))

    {score_list, _} =
      Enum.map_reduce(scoring_plays, %{home: 0, away: 0}, fn score, acc ->
        side = get_side(score, home_abbr)
        points = @score_types[score["note"]]
        scores = Map.update(acc, side, points, &(&1 + points))

        {Map.put(scores, :id, String.to_integer(score.id)), scores}
      end)

    {res, _} =
      Enum.map_reduce(plays, [], fn play, acc ->
        score =
          Enum.find(Enum.reverse(score_list), &(String.to_integer(play.id) >= &1[:id])) ||
            %{home: 0, away: 0}

        play_list = [play | acc]

        statistics = aggregate_stats(play_list)

        [away_stats, home_stats] =
          Enum.map([home_abbr, away_abbr], fn abbr ->
            Enum.filter(statistics, &(&1.team == abbr && Enum.member?(Map.keys(&1), :passing)))
            |> Enum.reduce(%{ints: 0, sacks: 0}, fn stats, res ->
              Enum.reduce([:sacks, :ints], res, fn category, res ->
              	value = Map.get(stats.passing, category, 0)
              	Map.update(res, category, value, &(&1 + value))
              end)
            end)
          end)

        statistics =
          List.flatten([
            aggregate_stats(play_list),
            defense(home_abbr, home_stats, score.away),
            defense(away_abbr, away_stats, score.home)
          ])
          |> Enum.map(&ContestTracker.Ingest.Scoring.calc_score/1)

        {%{description: play["desc"], id: play.id, play: play, statistics: statistics, sequence: String.to_integer(play.id), score: score}, play_list}
      end)

    # topic = "events"
    # client_id = :events_client
    # hosts = [localhost: 29092]

    # :ok = :brod.start_client(hosts, client_id, _client_config=[])
    # :ok = :brod.start_producer(client_id, topic, _producer_config = [])
    # Enum.each(res, fn play ->
    # 	partition = rem(String.to_integer(play.id), 3)
    # 	 :ok = :brod.produce_sync(client_id, topic, partition, _key="", Jason.encode!(play))
    # end)

    # payload = Enum.map(res, fn msg ->
    #   [%{index: %{"_index" => "plays", "_type" => "play"}}, Map.take(msg, [:id, :play, :description, :sequence, :score])]
    # end)
    # |> List.flatten

    # Elastix.Bulk.post("http://localhost:9200", payload, index: "plays", type: "play")
    res
  end
end
