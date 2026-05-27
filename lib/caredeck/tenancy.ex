defmodule Caredeck.Tenancy do
  alias Caredeck.Org.Facility
  alias Caredeck.Org.FacilityMembership

  def to_tenant(%Facility{id: id}), do: id
  def to_tenant(%FacilityMembership{facility_id: id}), do: id
  def to_tenant(%{facility_id: facility_id}) when is_binary(facility_id), do: facility_id
  def to_tenant(%{current_facility: %{id: id}}), do: id
  def to_tenant(facility_id) when is_binary(facility_id), do: facility_id

  def to_tenant(nil) do
    raise ArgumentError,
          "tenant required — got nil. Pass a %Facility{}, a %FacilityMembership{}, or a facility_id string."
  end

  def to_tenant(other) do
    raise ArgumentError, "cannot derive tenant from #{inspect(other)}"
  end
end
