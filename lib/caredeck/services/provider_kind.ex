defmodule Caredeck.Services.ProviderKind do
  @kinds ~w(pharmacy laundry podiatry hairdresser doctor physio florist)a

  def all, do: @kinds

  def label(:pharmacy), do: "Pharmacy"
  def label(:laundry), do: "Laundry"
  def label(:podiatry), do: "Podiatry"
  def label(:hairdresser), do: "Hairdresser"
  def label(:doctor), do: "Doctor"
  def label(:physio), do: "Physiotherapy"
  def label(:florist), do: "Florist"

  @subkinds %{
    pharmacy: ~w(prescription_upload medication_inquiry general_question)a,
    laundry: ~w(complaint)a,
    podiatry: ~w(appointment_request)a,
    hairdresser: ~w(appointment_request)a,
    doctor: ~w(appointment_request information_request)a,
    physio: ~w(appointment_request)a,
    florist: ~w(order)a
  }

  def subkinds_for(kind), do: Map.fetch!(@subkinds, kind)

  def default_subkind(kind), do: subkinds_for(kind) |> hd()
end
