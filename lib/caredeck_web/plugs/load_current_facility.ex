defmodule CaredeckWeb.Plugs.LoadCurrentFacility do
  import Plug.Conn

  require Ash.Query

  def init(opts), do: opts

  def call(conn, _opts) do
    facility =
      cond do
        team = conn.assigns[:current_team_identity] ->
          lookup_facility(team.facility_id)

        user = conn.assigns[:current_user] ->
          first_facility_for_user(user.id)

        true ->
          nil
      end

    assign(conn, :current_facility, facility)
  end

  defp lookup_facility(nil), do: nil

  defp lookup_facility(facility_id) do
    case Ash.get(Caredeck.Org.Facility, facility_id, authorize?: false) do
      {:ok, facility} -> facility
      _ -> nil
    end
  end

  defp first_facility_for_user(user_id) do
    case Ash.read_one(
           Caredeck.Org.FacilityMembership
           |> Ash.Query.filter(user_id == ^user_id)
           |> Ash.Query.load(:facility),
           authorize?: false
         ) do
      {:ok, %{facility: facility}} -> facility
      _ -> nil
    end
  end
end
