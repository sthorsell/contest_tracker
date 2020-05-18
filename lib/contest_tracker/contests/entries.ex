defmodule ContestTracker.Contests.Entries do
  @moduledoc """
  Module responsible for loading and modifying contest entries via Elasticsearch.
  """
  alias ContestTracker.Search

  def get_plays do
    {:ok, res} = Search.query("plays", "play", %{query: %{match_all: %{}}, sort: [%{sequence: %{order: :asc}}], size: 200})
    plays = res.body["hits"]["hits"]
    |> Enum.map(&(&1["_source"]))

    Enum.map(plays, fn play ->
      Map.take(play, ["id", "description", "score"])
      |> Map.put("quarter", play["play"]["quarter"])
      |> Map.put("note", play["play"]["note"])
    end)
  end

  def get_entries(play_id \\ "36") do
    query = %{query: %{match: %{"play.id.keyword": play_id}}, size: 10000}
    {:ok, res} = Search.scroll_init(query)
    List.flatten(Search.scroll_entries(res.body, []))
  end

  def round_amt(pts) when is_integer(pts), do: pts / 1
  def round_amt(pts), do: Float.round(pts, 2)

  defp calculate_payout(play_id \\ "36") do
    # Load Payout Structure
    %{"prizes" => prizes} = Jason.decode!(File.read!("data/contest.json"))
    payouts = Enum.map(prizes, fn prize ->
      %{"value" => amt, "maxFinish" => max, "minFinish" => min} = prize
      List.duplicate(amt, max - min + 1)
    end)
    |> List.flatten

    # Query to get unique points scored
    query = %{query: %{match: %{"play.id.keyword": play_id}}, size: 0, aggs: %{points: %{composite: %{size: 10000, sources: [%{points: %{terms: %{field: :points}}}]}}}}

    {:ok, %{body: %{"aggregations" => %{"points" => %{"buckets" => buckets}}}}} = Search.query("entries", "entry", query)
    {_, res} = Enum.sort_by(buckets, &(&1["key"]["points"]), :desc)
    |> Enum.reduce({payouts, %{}}, fn %{"doc_count" => count, "key" => pts}, {payouts, acc} ->
      {current, remaining} = Enum.split(payouts, count)
      total = round_amt(Enum.reduce(current, 0, &(&1 + &2)) / count)
      {remaining, Map.put(acc, pts, total)}
    end)

    # Update query
    Task.async_stream(res, fn {%{"points" => pts}, amt} ->
      {:ok, _} = ContestTracker.Search.update_by_query(play_id, round_amt(pts), amt)
    end, ordered: false, timeout: 1000 * 1000)
    |> Stream.run
  end

  def calculate_payouts do
    get_plays()
    |> Enum.each(fn %{"id" => id} ->
      calculate_payout(id)
    end)
  end

  def get_paginated_entries(play_id \\ "36", page \\ 0) do
    query = %{from: page * 10, query: %{match: %{"play.id.keyword": play_id}}, sort: [%{points: %{order: :desc}}, "username.keyword"], size: 10}
    {:ok, res} = Search.query("entries", "entry", query)
    plays = res.body["hits"]["hits"]
    |> Enum.map(&(&1["_source"]))
  end
end