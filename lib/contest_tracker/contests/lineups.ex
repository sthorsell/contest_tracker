defmodule ContestTracker.Contests.Lineups do
  @moduledoc """
  Module responsible for loading and retrieving contest lineups.
  """
  use Agent

  @doc """
  Starts a new bucket.
  """
  def start_link(_opts) do
    res = Agent.start_link(fn -> %{} end, name: __MODULE__)
    put(:entries, load_entries())
    res
  end

  @doc """
  Gets a value from the `bucket` by `key`.
  """
  def get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end

  @doc """
  Puts the `value` for the given `key` in the `bucket`.
  """
  def put(key, value) do
    Agent.update(__MODULE__, &Map.put(&1, key, value))
  end

  def load_entries() do
    File.read!("data/contest-standings-85042224.csv")
    |> String.split("\n", trim: true)
    |> Enum.slice(1..-1)
    |> Enum.map(fn row ->
      cols = String.split(row, ",")
      [display_name, lineup] = Enum.map([2, 5], &Enum.at(cols, &1))
      [username | _] = String.split(display_name, " ")

      {_, players} =
        String.split(lineup, ~r/\s?(FLEX|CPT)\s\s?/)
        |> Enum.split(1)

      {username, Enum.map(players, &String.trim/1)}
    end)
    |> Enum.map(fn {username, players} -> %{players: players, username: username} end)
  end
end
