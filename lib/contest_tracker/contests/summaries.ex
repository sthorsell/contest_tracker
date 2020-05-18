defmodule ContestTracker.Contests.Summaries do
  @moduledoc """
  Module responsible for loading and retrieving contest summary information.
  """
  use Agent

  @doc """
  Starts a new bucket.
  """
  def start_link(_opts) do
    res = Agent.start_link(fn -> %{} end, name: __MODULE__)
    put(:summary, load_summary())
    res
  end

  def get_summary, do: get(:summary)

  @doc """
  Gets a value from the `bucket` by `key`.
  """
  defp get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end

  @doc """
  Puts the `value` for the given `key` in the `bucket`.
  """
  defp put(key, value) do
    Agent.update(__MODULE__, &Map.put(&1, key, value))
  end

  defp load_summary() do
    Jason.decode!(File.read!("data/contest.json"))
  end
end
