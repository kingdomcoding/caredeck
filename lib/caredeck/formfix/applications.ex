defmodule Caredeck.Formfix.Applications do
  alias Caredeck.Formfix.{
    Application,
    ApplicationSection,
    MaritalStatus,
    RequiredDocuments,
    SectionAnswer,
    SectionSeeder,
    UploadedDocument
  }

  require Ash.Query

  def next_section_key(application, current_section_key) do
    fid = application.facility_id

    sections =
      ApplicationSection
      |> Ash.Query.filter(application_id == ^application.id)
      |> Ash.Query.sort(position: :asc)
      |> Ash.read!(tenant: fid, authorize?: false)

    keys = Enum.map(sections, & &1.section_key)
    idx = Enum.find_index(keys, &(&1 == current_section_key))

    case idx do
      nil -> nil
      i when i + 1 < length(keys) -> Enum.at(keys, i + 1)
      _ -> nil
    end
  end

  def next_actionable_section(application) do
    fid = application.facility_id

    sections =
      ApplicationSection
      |> Ash.Query.filter(application_id == ^application.id)
      |> Ash.Query.sort(position: :asc)
      |> Ash.read!(tenant: fid, authorize?: false)

    Enum.find(sections, &(&1.status == :in_progress)) ||
      Enum.find(sections, &(&1.status == :not_started))
  end

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

  def refresh_conditional_sections(application) do
    fid = application.facility_id
    conditional_keys = Caredeck.Formfix.SectionKey.conditional()

    marital_atom =
      SectionAnswer
      |> Ash.Query.filter(
        application_id == ^application.id and
          section_key == :person_needing_care and
          field_key == :marital_status
      )
      |> Ash.read_one!(tenant: fid, authorize?: false)
      |> case do
        nil -> nil
        ans -> ans.value_atom
      end

    needed =
      if marital_atom && MaritalStatus.requires_spouse_section?(marital_atom),
        do: MapSet.new(conditional_keys),
        else: MapSet.new()

    existing =
      ApplicationSection
      |> Ash.Query.filter(
        application_id == ^application.id and section_key in ^conditional_keys
      )
      |> Ash.read!(tenant: fid, authorize?: false)

    existing_keys = MapSet.new(Enum.map(existing, & &1.section_key))

    Enum.each(MapSet.difference(needed, existing_keys), fn key ->
      ApplicationSection
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: fid,
          application_id: application.id,
          section_key: key,
          position: Caredeck.Formfix.SectionKey.position(key),
          status: :not_started
        },
        tenant: fid,
        authorize?: false
      )
      |> Ash.create!(tenant: fid, authorize?: false)
    end)

    Enum.each(existing, fn section ->
      unless MapSet.member?(needed, section.section_key) do
        Ash.destroy!(section, tenant: fid, authorize?: false)
      end
    end)

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
