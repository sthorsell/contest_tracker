defmodule ContestTracker.Search do
  @moduledoc """
  Module responsible for communicating with Elasticsearch.
  """
  import Elastix.HTTP, only: [prepare_url: 2]
  alias Elastix.{HTTP, JSON}

  @url Application.fetch_env!(:elastix, :host)

  def create_indices do
    # Elastix.Index.create("http://localhost:9200", "entries", %{mappings: @mapping})
    Elastix.Index.create(@url, "entries", %{})
  end

  def scroll_init(data, options \\ []) do
    prepare_url("#{@url}/entries/", "_search?scroll=20m")
    |> HTTP.post(JSON.encode!(data), [], options)
  end

  def scroll_entries(%{"_scroll_id" => _scroll, "hits" => %{"hits" => []}}, acc) do
    acc
  end

  def scroll_entries(%{"_scroll_id" => scroll, "hits" => %{"hits" => hits}}, acc) do
    {:ok, res} = Elastix.Search.scroll(@url, %{scroll_id: scroll, scroll: "5m"})
    scroll_entries(res.body, [hits | acc])
  end

  def update_by_query(play, points, value) do
    query = %{
      query: %{
        bool: %{
          must: [
            %{
              match: %{
                "play.id.keyword": "#{play}"
              }
            },
            %{
              match: %{
                points: points
              }
            }
          ]
        }
      },
      script: %{
        source: "ctx._source.winning=#{value}",
        lang: "painless"
      }
    }

    prepare_url("#{@url}/entries/", "_update_by_query?routing=1")
    |> HTTP.post(JSON.encode!(query), [], recv_timeout: 300 * 1000)
  end

  def query(index, type, query) do
    Elastix.Search.search(@url, index, [type], query)
  end

  def bulk(index, type, payload) do
    Elastix.Bulk.post(@url, payload, index: index, type: type)
  end
end
