defmodule Caredeck.Aid.SectionSeeder do
  alias Caredeck.Aid.{ApplicationSection, SectionKey}

  def materialise!(%{id: application_id, facility_id: facility_id} = _application) do
    SectionKey.base()
    |> Enum.with_index(1)
    |> Enum.each(fn {key, position} ->
      ApplicationSection
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility_id,
          application_id: application_id,
          section_key: key,
          position: position,
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
