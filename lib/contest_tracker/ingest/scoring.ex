defmodule ContestTracker.Ingest.Scoring do
  @moduledoc """
  Module responsible for calculating fantasy points.
  """
	@scoring_map %{
    passing: %{yards: 0.04, touchdowns: 4, ints: -1},
    rushing: %{yards: 0.1, touchdowns: 6},
    receiving: %{yards: 0.1, touchdowns: 6, receptions: 1},
    kicking: %{xp: 1, fg_3: 3, fg_4: 4, fg_5: 5},
    defense: %{ints: 2, sacks: 1}
  }

  def calculate(nil, _), do: 0
	def calculate(stats, props) do
		Enum.reduce(props, 0, fn {prop, value}, res ->
			Map.get(stats, prop, 0) * value + res
		end)
	end

	def score_for(_, nil), do: 0
	def score_for(:defense, stats) do
		defense_points(stats.points) + calculate(stats, @scoring_map.defense)
	end
  def score_for(:passing, stats) do
    passing_yards_bonus(stats.yards) + calculate(stats, @scoring_map.passing)
  end
  def score_for(:kicking, stats) do
    calculate(stats, @scoring_map.kicking)
  end
  def score_for(category, stats) when category in [:rushing, :receiving] do
    yards_bonus(stats.yards) + calculate(stats, Map.get(@scoring_map, category))
  end

	def defense_points(0), do: 10
	def defense_points(pts) when pts < 7, do: 7
	def defense_points(pts) when pts < 14, do: 4
	def defense_points(pts) when pts < 21, do: 1
	def defense_points(pts) when pts < 28, do: 0
	def defense_points(pts) when pts < 35, do: -1
	def defense_points(_), do: -4

  def yards_bonus(yds) when yds > 99, do: 3
  def yards_bonus(_), do: 0
  def passing_yards_bonus(yds) when yds > 299, do: 3
  def passing_yards_bonus(_), do: 0

  def round_points(pts) when is_integer(pts), do: pts
  def round_points(pts), do: Float.round(pts, 2)

	def calc_score(stats) do
		points = Enum.reduce([:passing, :rushing, :receiving, :defense, :kicking], 0, fn category, res ->
      score_for(category, Map.get(stats, category)) + res
		end)

    Map.put(stats, :dk_points, round_points(points))
	end
end