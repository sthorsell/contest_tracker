defmodule ContestTrackerWeb.ApiController do
  use ContestTrackerWeb, :controller

  def index(conn, _params) do
  	json(conn, ContestTracker.Contests.Entries.get_plays)
  end

  def entries(conn, %{"page" => page, "id" => id}) do 
  	json(conn, ContestTracker.Contests.Entries.get_paginated_entries(id, String.to_integer(page)))
  end

  def summary(conn, _) do 
  	contest = ContestTracker.Contests.Summaries.get_summary
  	props = Map.take(contest, ["name", "entryFee", "entryCount"])

  	payouts = Enum.map(contest["prizes"], fn prize -> 
  		%{amount: prize["cash"], min: prize["minFinish"], max: prize["maxFinish"]}
  	end)

  	res = Map.put(props, :payouts, payouts)

  	json(conn, res)
  end
end
