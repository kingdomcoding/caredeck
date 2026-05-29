defmodule Caredeck.Aid.SectionWriter do
  alias Caredeck.Aid.{ApplicationSection, SectionAnswer, SectionSchema}

  require Ash.Query

  def save_answers!(application, section_key, params) do
    facility_id = application.facility_id
    schema_fields = SectionSchema.fields(section_key)

    Enum.each(schema_fields, fn field ->
      raw = Map.get(params, Atom.to_string(field.key)) || Map.get(params, field.key)
      maybe_save_field(application, section_key, field, raw, facility_id)
    end)

    new_status =
      if SectionSchema.complete?(section_key, current_answer_map(application, section_key)) do
        :complete
      else
        :in_progress
      end

    section =
      ApplicationSection
      |> Ash.Query.filter(application_id == ^application.id and section_key == ^section_key)
      |> Ash.read_one!(tenant: facility_id, authorize?: false)

    section
    |> Ash.Changeset.for_update(:transition, %{status: new_status},
      tenant: facility_id,
      authorize?: false
    )
    |> Ash.update!(tenant: facility_id, authorize?: false)

    if section_key == :person_needing_care do
      :ok = Caredeck.Aid.Applications.refresh_conditional_sections(application)
    end

    :ok = Caredeck.Aid.Applications.recompute_status(application)

    :ok
  end

  defp maybe_save_field(_app, _section_key, _field, raw, _facility_id) when raw in [nil, ""],
    do: :skip

  defp maybe_save_field(application, section_key, field, raw, facility_id) do
    with {:ok, parsed} <- SectionSchema.parse(field.kind, raw) do
      attrs =
        %{
          facility_id: facility_id,
          application_id: application.id,
          section_key: section_key,
          field_key: field.key
        }
        |> Map.put(SectionSchema.value_column(field.kind), parsed)

      SectionAnswer
      |> Ash.Changeset.for_create(:create, attrs, tenant: facility_id, authorize?: false)
      |> Ash.create!(tenant: facility_id, authorize?: false)
    end
  end

  defp current_answer_map(application, section_key) do
    SectionAnswer
    |> Ash.Query.filter(application_id == ^application.id and section_key == ^section_key)
    |> Ash.read!(tenant: application.facility_id, authorize?: false)
    |> Map.new(&{&1.field_key, value_of(&1)})
  end

  defp value_of(%{value_text: v}) when not is_nil(v), do: v
  defp value_of(%{value_date: v}) when not is_nil(v), do: v
  defp value_of(%{value_bool: v}) when not is_nil(v), do: v
  defp value_of(%{value_decimal: v}) when not is_nil(v), do: v
  defp value_of(%{value_atom: v}) when not is_nil(v), do: v
  defp value_of(_), do: nil
end
