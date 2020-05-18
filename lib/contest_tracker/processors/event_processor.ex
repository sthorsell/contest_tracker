defmodule ContestTracker.Processors.EventProcessor do
  use Broadway

  @name_map %{
    "B.Bell" => "Blake Bell",
    "D.Samuel" => "Deebo Samuel",
    "D.Thompson" => "Darwin Thompson",
    "Dam.Williams" => "Damien Williams",
    "E.Sanders" => "Emmanuel Sanders",
    "G.Kittle" => "George Kittle",
    "H.Butker" => "Harrison Butker",
    "J.Garoppolo" => "Jimmy Garoppolo",
    "J.Wilson" => "Jeff Wilson",
    "K.Bourne" => "Kendrick Bourne",
    "K.Juszczyk" => "Kyle Juszczyk",
    "KC" => "Chiefs",
    "M.Hardman" => "Mecole Hardman",
    "P.Mahomes" => "Patrick Mahomes",
    "R.Gould" => "Robbie Gould",
    "R.Mostert" => "Raheem Mostert",
    "S.Watkins" => "Sammy Watkins",
    "SF" => "49ers",
    "T.Coleman" => "Tevin Coleman",
    "T.Hill" => "Tyreek Hill",
    "T.Kelce" => "Travis Kelce"
  }

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {BroadwayKafka.Producer, [
          hosts: [localhost: 29092],
          group_id: "group_1",
          topics: ["events"],
          offset_reset_policy: :earliest
        ]},
        concurrency: 20
      ],
      processors: [
        default: [
          concurrency: 20
        ]
      ]
    )
  end

  def round_points(pts) when is_integer(pts), do: pts
  def round_points(pts), do: Float.round(pts, 2)

  def hydrate_player(name, pts, pos \\ "FLEX")
  def hydrate_player(name, pts, "CPT"), do: %{name: name, position: "CPT", points: round_points(1.5 * pts)}
  def hydrate_player(name, pts, "FLEX"), do: %{name: name, position: "FLEX", points: round_points(pts)}

  @impl true
  def handle_message(_, message, _) do
    play = Jason.decode!(message.data)
    points_map = Enum.reduce(play["statistics"], %{}, fn %{"name" => name, "dk_points" => pts}, res -> 
      Map.put(res, Map.get(@name_map, name), pts)
    end)

    entries = ContestTracker.Contests.Lineups.get(:entries)

    Enum.chunk_every(entries, 150)  
    |> Task.async_stream(fn group ->
      messages = Enum.map(group, fn entry -> 
        {flexs, cpt} = Enum.split(entry.players, -1)

        lineup = Enum.zip([flexs, cpt], ["FLEX", "CPT"])
        |> Enum.map(fn {players, pos} -> 
          Enum.map(players, fn name -> 
            hydrate_player(name, Map.get(points_map, name, 0), pos)
          end)
        end)
        |> List.flatten
        
        points = round_points(Enum.reduce(lineup, 0, &(&1.points + &2)))

        payload = %{
          players: lineup, points: points, username: entry.username,
          play: %{id: play["id"], description: play["description"]},
          winning: 10.0
        }        

        {play["id"], Jason.encode!(payload)}
      end) 
      

      topic = "entries"
      client_id = :entries_client
      hosts = [localhost: 29092]

      :brod.start_client(hosts, client_id, _client_config=[])
      :brod.start_producer(client_id, topic, _producer_config = [])
      partition = rem(String.to_integer(play["id"]), 3)

      :brod.produce_sync(client_id, topic, partition, _key="", messages)
    end, ordered: false, timeout: 100000)
    |> Stream.run

    message
  end
end