defmodule Caredeck.Kitchen.Materialise do
  alias Caredeck.Kitchen.{DayMenu, DayMenuSlot, MenuTemplate, MenuTemplateSlot}

  require Ash.Query

  def materialise_day(facility_id, %Date{} = date) do
    template = active_template(facility_id)
    day = date |> Date.day_of_week() |> day_atom()

    day_menu =
      DayMenu
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility_id,
          date: date,
          materialised_from_template_id: template && template.id
        },
        tenant: facility_id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility_id, authorize?: false)

    if template do
      MenuTemplateSlot
      |> Ash.Query.filter(menu_template_id == ^template.id and day_of_week == ^day)
      |> Ash.read!(tenant: facility_id, authorize?: false)
      |> Enum.each(fn s ->
        DayMenuSlot
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: facility_id,
            day_menu_id: day_menu.id,
            category: s.category,
            product_id: s.product_id
          },
          tenant: facility_id,
          authorize?: false
        )
        |> Ash.create!(tenant: facility_id, authorize?: false)
      end)
    end

    Ash.load!(day_menu, [slots: [:product]], tenant: facility_id, authorize?: false)
  end

  defp active_template(facility_id) do
    MenuTemplate
    |> Ash.Query.filter(is_active == true)
    |> Ash.read_one!(tenant: facility_id, authorize?: false)
  end

  defp day_atom(1), do: :monday
  defp day_atom(2), do: :tuesday
  defp day_atom(3), do: :wednesday
  defp day_atom(4), do: :thursday
  defp day_atom(5), do: :friday
  defp day_atom(6), do: :saturday
  defp day_atom(7), do: :sunday
end
