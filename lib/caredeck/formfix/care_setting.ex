defmodule Caredeck.Formfix.CareSetting do
  @values ~w(home day_care residential)a

  def all, do: @values

  def label(:home), do: "At home"
  def label(:day_care), do: "Day care"
  def label(:residential), do: "Residential"
end
