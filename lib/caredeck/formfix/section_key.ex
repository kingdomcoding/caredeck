defmodule Caredeck.Formfix.SectionKey do
  @ordered ~w(welcome person_needing_care applicant care_situation income
              income_partner assets assets_partner gifts_given
              gifts_given_partner expenses disability foreign_nationality
              spouse)a

  @conditional ~w(income_partner assets_partner gifts_given_partner spouse)a

  @positions @ordered |> Enum.with_index(1) |> Map.new()

  def all, do: @ordered
  def base, do: Enum.reject(@ordered, &conditional?/1)
  def conditional, do: @conditional

  def conditional?(key), do: key in @conditional

  def position(key), do: Map.fetch!(@positions, key)

  def label(:welcome), do: "Welcome"
  def label(:person_needing_care), do: "Person Needing Care"
  def label(:applicant), do: "Applicant"
  def label(:care_situation), do: "Care Situation"
  def label(:income), do: "Income"
  def label(:income_partner), do: "Income — Partner"
  def label(:assets), do: "Assets"
  def label(:assets_partner), do: "Assets — Partner"
  def label(:gifts_given), do: "Gifts Given"
  def label(:gifts_given_partner), do: "Gifts Given — Partner"
  def label(:expenses), do: "Expenses"
  def label(:disability), do: "Disability"
  def label(:foreign_nationality), do: "Foreign-Nationality Status"
  def label(:spouse), do: "Spouse"

  def next_key(current) do
    idx = Enum.find_index(@ordered, &(&1 == current))

    cond do
      is_nil(idx) -> nil
      idx + 1 >= length(@ordered) -> nil
      true -> Enum.at(@ordered, idx + 1)
    end
  end
end
