defmodule Caredeck.Aid.Applications do
  alias Caredeck.Aid.{Application, ApplicationSection, RequiredDocuments, SectionSeeder, UploadedDocument}

  require Ash.Query

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

  def recompute_status(application) do
    fid = application.facility_id

    sections =
      ApplicationSection
      |> Ash.Query.filter(application_id == ^application.id)
      |> Ash.read!(tenant: fid, authorize?: false)

    all_done? = Enum.all?(sections, &(&1.status in [:complete, :skipped]))
    docs_ok? = all_required_documents_verified?(application, sections)

    new_state =
      cond do
        application.state == :submitted -> nil
        application.state == :approved -> nil
        all_done? and docs_ok? -> :ready_to_submit
        all_done? and not docs_ok? -> :missing_documents
        true -> :draft
      end

    cond do
      is_nil(new_state) ->
        :ok

      new_state == application.state ->
        :ok

      true ->
        do_transition(application, new_state, fid)
    end
  end

  defp do_transition(app, :ready_to_submit, fid),
    do: do_apply(app, :mark_ready_to_submit, fid)

  defp do_transition(app, :missing_documents, fid),
    do: do_apply(app, :mark_missing_documents, fid)

  defp do_transition(_app, :draft, _fid), do: :ok

  defp do_apply(app, action, fid) do
    {:ok, _} =
      app
      |> Ash.Changeset.for_update(action, %{}, tenant: fid, authorize?: false)
      |> Ash.update(tenant: fid, authorize?: false)

    :ok
  end

  defp all_required_documents_verified?(application, sections) do
    active_section_keys =
      sections
      |> Enum.reject(&(&1.status == :skipped))
      |> Enum.map(& &1.section_key)

    needed =
      active_section_keys
      |> Enum.flat_map(fn key ->
        RequiredDocuments.for(key) |> Enum.map(&{key, &1.key})
      end)
      |> MapSet.new()

    if MapSet.size(needed) == 0 do
      true
    else
      verified =
        UploadedDocument
        |> Ash.Query.filter(application_id == ^application.id)
        |> Ash.read!(tenant: application.facility_id, authorize?: false)
        |> Enum.filter(&(&1.state == :verified))
        |> Enum.map(&{&1.section_key, &1.document_key})
        |> MapSet.new()

      MapSet.subset?(needed, verified)
    end
  end
end
