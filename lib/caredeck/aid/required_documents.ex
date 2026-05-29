defmodule Caredeck.Aid.RequiredDocuments do
  @docs %{
    person_needing_care: [
      %{
        key: :id_card,
        label: "Identity card or passport",
        legal_note: "Photo and biographic-data pages. Either side of a national ID card is fine."
      }
    ],
    care_situation: [
      %{
        key: :care_level_notice,
        label: "Care-level approval notice",
        legal_note:
          "Approval notice from the long-term-care insurer, including care level and benefit amount."
      }
    ],
    income: [
      %{
        key: :pension_statement,
        label: "Pension statement (most recent)",
        legal_note: "Most recent annual or quarterly pension statement."
      },
      %{
        key: :bank_statement_3mo,
        label: "Bank statements (last 3 months)",
        legal_note: "All accounts, including any rarely-used savings accounts."
      }
    ],
    assets: [
      %{
        key: :property_deed,
        label: "Property deed (if applicable)",
        legal_note: "Only required if the person needing care owns property."
      }
    ],
    expenses: [
      %{
        key: :rental_contract,
        label: "Rental contract",
        legal_note: "Only required if the person needing care rents their home."
      }
    ],
    disability: [
      %{
        key: :disability_id,
        label: "Disability ID card",
        legal_note: "Front and back of the disability ID card."
      }
    ]
  }

  def for(section_key), do: Map.get(@docs, section_key, [])

  def all_required do
    Enum.flat_map(@docs, fn {section, slots} ->
      Enum.map(slots, fn slot -> {section, slot.key} end)
    end)
  end
end
