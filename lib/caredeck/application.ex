defmodule Caredeck.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @mix_env Mix.env()

  @impl true
  def start(_type, _args) do
    warn_if_formfix_stub()

    children = [
      CaredeckWeb.Telemetry,
      Caredeck.Repo,
      {DNSCluster, query: Application.get_env(:caredeck, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Caredeck.PubSub},
      {Task.Supervisor, name: Caredeck.TaskSupervisor},
      {Oban, Application.fetch_env!(:caredeck, Oban)},
      CaredeckWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Caredeck.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp warn_if_formfix_stub do
    if @mix_env == :prod and
         Application.get_env(:caredeck, :formfix_verification_engine, :stub) == :stub do
      require Logger

      Logger.warning(
        "[Formfix] verification engine is :stub — replace before real applicants are onboarded."
      )
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CaredeckWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
