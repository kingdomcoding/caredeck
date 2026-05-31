defmodule Caredeck.Formfix.Money do
  @monthly_fields ~w(pension_eur_month rent_eur_month other_eur_month
                     partner_pension_eur_month partner_rent_eur_month partner_other_eur_month
                     rent_eur_month)a

  @total_fields ~w(savings_eur property_value_eur
                   partner_savings_eur partner_property_value_eur)a

  def monthly?(field_key), do: field_key in @monthly_fields
  def total?(field_key), do: field_key in @total_fields
  def money?(field_key), do: monthly?(field_key) or total?(field_key)

  def format(nil), do: "—"

  def format(%Decimal{} = d) do
    int = d |> Decimal.round(0, :down) |> Decimal.to_integer()
    "€" <> format_thousands(int) <> ",00"
  end

  def format(n) when is_integer(n) do
    "€" <> format_thousands(n) <> ",00"
  end

  def format_for_field(value, field_key) do
    formatted = format(value)

    cond do
      monthly?(field_key) -> formatted <> " /Monat"
      true -> formatted
    end
  end

  defp format_thousands(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.join/1)
    |> Enum.join(".")
    |> String.reverse()
  end
end
