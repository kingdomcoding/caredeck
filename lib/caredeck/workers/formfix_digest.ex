defmodule Caredeck.Workers.FormfixDigest do
  use Oban.Worker, queue: :mailers, max_attempts: 3

  alias Caredeck.Accounts.TeamIdentity
  alias Caredeck.Formfix.{Application, ApplicationNote, Applications, DigestEmail}
  alias Caredeck.Org.Facility
  alias Caredeck.Mailer

  require Ash.Query

  @impl true
  def perform(%Oban.Job{args: %{"facility_id" => fid}}) do
    facility = Ash.get!(Facility, fid, authorize?: false)

    admins =
      TeamIdentity
      |> Ash.Query.filter(facility_id == ^fid and role_kind == :admin)
      |> Ash.Query.sort(inserted_at: :asc)
      |> Ash.read!(authorize?: false)

    case admins do
      [] ->
        :ok

      admins ->
        apps = load_applications(facility)
        newly_approved = Enum.filter(apps, &recently_approved?/1)

        email = DigestEmail.build(facility, admins, apps, newly_approved)
        {:ok, _} = Mailer.deliver(email)
        :ok
    end
  end

  defp load_applications(facility) do
    Application
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.load([:resident, :applicant_user, :applicant_team])
    |> Ash.read!(tenant: facility.id, authorize?: false)
    |> Enum.map(fn a ->
      Map.merge(a, %{
        total_progress: Applications.total_progress_percent(a),
        notes: load_notes(a, facility)
      })
    end)
  end

  defp load_notes(app, facility) do
    ApplicationNote
    |> Ash.Query.filter(application_id == ^app.id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(3)
    |> Ash.read!(tenant: facility.id, authorize?: false)
  end

  defp recently_approved?(%{state: :approved, decided_at: %DateTime{} = dt}),
    do: DateTime.diff(DateTime.utc_now(), dt, :day) <= 7

  defp recently_approved?(_), do: false
end
