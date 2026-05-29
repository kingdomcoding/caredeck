defmodule Caredeck.Formfix.MaritalStatus do
  @values ~w(single married domestic_partnership registered_civil_partnership
             widowed divorced permanently_separated civil_partnership_dissolved
             unknown)a

  def all, do: @values

  def label(:single), do: "Single"
  def label(:married), do: "Married"
  def label(:domestic_partnership), do: "Domestic partnership"
  def label(:registered_civil_partnership), do: "Registered civil partnership"
  def label(:widowed), do: "Widowed"
  def label(:divorced), do: "Divorced"
  def label(:permanently_separated), do: "Permanently separated"
  def label(:civil_partnership_dissolved), do: "Civil partnership dissolved"
  def label(:unknown), do: "Unknown / prefer not to say"

  def requires_spouse_section?(s)
      when s in [:married, :domestic_partnership, :registered_civil_partnership],
      do: true

  def requires_spouse_section?(_), do: false
end
