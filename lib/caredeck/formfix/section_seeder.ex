defmodule Caredeck.Formfix.SectionSeeder do
  alias Caredeck.Formfix.{ApplicationSection, SectionKey}

  def materialise!(%{id: application_id, facility_id: facility_id} = _application) do
    Enum.each(SectionKey.base(), fn key ->
      ApplicationSection
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility_id,
          application_id: application_id,
          section_key: key,
          position: SectionKey.position(key),
          status: :not_started
        },
        tenant: facility_id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility_id, authorize?: false)
    end)

    :ok
  end
end
