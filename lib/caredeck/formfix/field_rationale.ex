defmodule Caredeck.Formfix.FieldRationale do
  @rationales %{
    {:person_needing_care, :marital_status} =>
      "The marital status of the person needing care affects various welfare-law questions — for example, support obligations, household composition, and the documents required.",
    {:person_needing_care, :postal_code} =>
      "Your postal code determines which local welfare office is responsible for processing the application.",
    {:person_needing_care, :date_of_birth} =>
      "The applicant's date of birth lets the welfare office check age-related allowances and confirm identity.",
    {:applicant, :relationship} =>
      "We ask about your relationship so the welfare office knows who is acting on the applicant's behalf and which legal-representation rules apply.",
    {:applicant, :email} =>
      "We will only use your email to send status updates about this application — no marketing, ever.",
    {:care_situation, :care_level} =>
      "The assigned care level (1–5) determines the baseline benefit amount and which documents the welfare office expects to see.",
    {:care_situation, :setting} =>
      "Where care is currently provided (at home, day care, or residential) changes which costs are eligible for assistance.",
    {:income, :pension_eur_month} =>
      "Pension income is the primary income figure the welfare office uses to calculate the household contribution.",
    {:assets, :savings_eur} =>
      "Savings above the welfare-law exemption threshold may be expected to be used before public funds are granted. Quote the figure on your most recent bank statement.",
    {:assets, :property_value_eur} =>
      "Property value can sometimes be excluded from the means assessment if it is the primary residence. Quote a rough current-market figure.",
    {:gifts_given, :any_gifts_over_500} =>
      "Gifts above €500 made in the last 10 years are reviewable under the gift-reversal rules — the welfare office may ask the recipient to refund part or all of the gift.",
    {:expenses, :rent_eur_month} =>
      "Rent is the largest deductible expense in the means assessment. Quote the figure from your most recent rental agreement or statement.",
    {:disability, :has_disability_status} =>
      "An officially recognised disability status can grant additional allowances and changes the documents you need to provide.",
    {:disability, :degree_percent} =>
      "The recognised degree of disability (in %) is taken from the disability ID card.",
    {:foreign_nationality, :nationality} =>
      "Applicants with foreign nationality may need to provide proof of legal residence and may be subject to different processing timelines.",
    {:foreign_nationality, :years_in_country} =>
      "Continuous residence over several years can unlock more processing options."
  }

  def for(section_key, field_key), do: Map.get(@rationales, {section_key, field_key})
end
