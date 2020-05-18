defmodule ContestTracker.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      ContestTrackerWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: ContestTracker.PubSub},
      # Start the Endpoint (http/https)
      ContestTrackerWeb.Endpoint,
      ContestTracker.Contests.Summaries,
      ContestTracker.Contests.Lineups,
      ContestTracker.Processors.EventProcessor,
      ContestTracker.Processors.EntryProcessor
      # Start a worker by calling: ContestTracker.Worker.start_link(arg)
      # {ContestTracker.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ContestTracker.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    ContestTrackerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
