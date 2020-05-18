defmodule ContestTracker.Processors.EntryProcessor do
  use Broadway

  alias Broadway.Message

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module:
          {BroadwayKafka.Producer,
           [
             hosts: [localhost: 29092],
             group_id: "group_1",
             topics: ["entries"],
             offset_reset_policy: :earliest
           ]},
        concurrency: 40
      ],
      processors: [
        default: [
          concurrency: 40
        ]
      ],
      batchers: [
        default: [
          batch_size: 2000,
          batch_timeout: 500,
          concurrency: 30
        ]
      ]
    )
  end

  @impl true
  def handle_message(_, message, _) do
    Message.update_data(message, &Jason.decode!/1)
  end

  @impl true
  def handle_batch(_, messages, _, _) do
    payload =
      Enum.map(messages, fn msg ->
        data =
          msg.data
          |> Map.put("winning", 0.0)
          |> Map.put("points", msg.data["points"] / 1)

        [%{index: %{"_index" => "entries", "_type" => "entry"}}, data]
      end)
      |> List.flatten()

    {:ok, _} = ContestTracker.Search.bulk("entries", "entry", payload)

    messages
  end
end
