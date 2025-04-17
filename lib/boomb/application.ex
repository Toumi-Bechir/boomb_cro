defmodule Boomb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do

    :mnesia.create_schema([node()])
    :mnesia.start()
    # Wait for Mnesia to be fully started
    #:mnesia.wait_for_tables([:event], 5000)


    Boomb.Event.create_table()

    children = [
      BoombWeb.Telemetry,
      Boomb.Repo,
      {DNSCluster, query: Application.get_env(:boomb, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Boomb.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Boomb.Finch},
      # Start a worker by calling: Boomb.Worker.start_link(arg)
      # {Boomb.Worker, arg},
      # Start to serve requests, typically the last entry
      BoombWeb.Endpoint,
      Boomb.GoalserveToken,
      Boomb.SportsCache,
      #Boomb.OddsCache,
      %{
      id: Boomb.OddsCache,
      start: {Boomb.OddsCache, :start_link, ["ztart"]}
      },
      Boomb.OddsThrottler,
      {Boomb.GoalserveWebsocketSupervisor, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Boomb.Supervisor]
    Supervisor.start_link(children, opts)
  end
@impl true
  def stop(_state) do
    :mnesia.stop()
    :ok
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BoombWeb.Endpoint.config_change(changed, removed)
    :ok
  end


end
