defmodule Caredeck.Feed.Authz do
  require Ash.Query

  alias Caredeck.{Accounts, Org, People}

  def same_facility?(%Accounts.User{} = user, facility_id) do
    case Ash.read_one(
           Org.FacilityMembership
           |> Ash.Query.filter(user_id == ^user.id and facility_id == ^facility_id),
           authorize?: false
         ) do
      {:ok, %{}} -> true
      _ -> false
    end
  end

  def same_facility?(%Accounts.TeamIdentity{} = team, facility_id) do
    team.facility_id == facility_id
  end

  def same_facility?(_, _), do: false

  def user_in_post_audience?(%Accounts.User{id: user_id}, post) do
    audience_ids = Enum.map(post.audience || [], & &1.id)

    if audience_ids == [] do
      false
    else
      relatives =
        People.Relative
        |> Ash.Query.filter(user_id == ^user_id)
        |> Ash.read!(tenant: post.facility_id, authorize?: false)

      relative_ids = Enum.map(relatives, & &1.id)

      if relative_ids == [] do
        false
      else
        People.RelativeOfResident
        |> Ash.Query.filter(relative_id in ^relative_ids and resident_id in ^audience_ids)
        |> Ash.read!(tenant: post.facility_id, authorize?: false)
        |> Kernel.!=([])
      end
    end
  end

  def user_in_post_audience?(_, _), do: false
end
