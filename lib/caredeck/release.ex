defmodule Caredeck.Release do
  @app :caredeck

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed do
    load_app()
    Application.ensure_all_started(:caredeck)
    Caredeck.Release.Seeds.run()
  end

  def refresh_demo_data do
    load_app()
    Application.ensure_all_started(:caredeck)
    Caredeck.Release.Seeds.refresh!()
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
