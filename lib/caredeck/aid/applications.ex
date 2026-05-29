defmodule Caredeck.Aid.Applications do
  alias Caredeck.Aid.{Application, SectionSeeder}

  def start_for_resident!(facility, resident, actor) do
    {applicant_user_id, applicant_team_id} =
      case actor do
        %Caredeck.Accounts.User{id: id} -> {id, nil}
        %Caredeck.Accounts.TeamIdentity{id: id} -> {nil, id}
        _ -> {nil, nil}
      end

    {:ok, app} =
      Application
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          resident_id: resident.id,
          applicant_user_id: applicant_user_id,
          applicant_team_id: applicant_team_id
        },
        tenant: facility.id,
        actor: actor
      )
      |> Ash.create(tenant: facility.id, actor: actor)

    :ok = SectionSeeder.materialise!(app)
    app
  end
end
