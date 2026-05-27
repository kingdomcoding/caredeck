defmodule Caredeck.Release.Seeds do
  alias Caredeck.Accounts
  alias Caredeck.Org
  alias Caredeck.People

  require Ash.Query

  @relative_email "demo-relative@example.test"
  @demo_password "phase1-demo-pass"

  @team_seeds [
    %{name: "Team Care", handle: "team-care", role_kind: :care},
    %{name: "Team Activities", handle: "team-activities", role_kind: :activities},
    %{name: "Team Therapy", handle: "team-therapy", role_kind: :therapy}
  ]

  @resident_seeds [
    %{first_name: "Erika", last_name: "Schmidt", date_of_birth: ~D[1944-09-15]},
    %{first_name: "Dietrich", last_name: "Manner", date_of_birth: ~D[1938-04-02]},
    %{first_name: "Marie", last_name: "Becker", date_of_birth: ~D[1940-11-22]}
  ]

  def run do
    district = find_or_create_district()
    facility = find_or_create_facility(district)
    find_or_create_ward(facility)
    Enum.each(@team_seeds, &find_or_create_team(&1, facility))
    relative = find_or_create_relative()
    find_or_create_membership(relative, facility)
    find_or_create_residents(facility)

    IO.puts("")
    IO.puts("Sandbox facility ready.")
    IO.puts("  Relative: #{@relative_email} / #{@demo_password}")
    IO.puts("  Teams:    team-care · team-activities · team-therapy / #{@demo_password}")
    IO.puts("  Residents: #{length(@resident_seeds)} seeded")
    IO.puts("")

    :ok
  end

  defp find_or_create_residents(facility) do
    for attrs <- @resident_seeds do
      query =
        People.Resident
        |> Ash.Query.filter(
          first_name == ^attrs.first_name and last_name == ^attrs.last_name
        )

      case Ash.read_one(query, tenant: facility.id, authorize?: false) do
        {:ok, nil} ->
          People.Resident
          |> Ash.Changeset.for_create(
            :create,
            Map.put(attrs, :facility_id, facility.id),
            tenant: facility.id,
            authorize?: false
          )
          |> Ash.create!(tenant: facility.id, authorize?: false)

        {:ok, _existing} ->
          :ok
      end
    end
  end

  defp find_or_create_district do
    find_or_create(
      Org.District |> Ash.Query.filter(slug == "sandbox"),
      Org.District,
      %{name: "Sandbox District", slug: "sandbox"}
    )
  end

  defp find_or_create_facility(district) do
    find_or_create(
      Org.Facility |> Ash.Query.filter(slug == "sandbox-home"),
      Org.Facility,
      %{district_id: district.id, name: "Sandbox Care Home", slug: "sandbox-home"}
    )
  end

  defp find_or_create_ward(facility) do
    find_or_create(
      Org.Ward |> Ash.Query.filter(facility_id == ^facility.id and name == "Ground Floor"),
      Org.Ward,
      %{facility_id: facility.id, name: "Ground Floor"}
    )
  end

  defp find_or_create_team(%{handle: handle, name: name, role_kind: role_kind}, facility) do
    case Ash.read_one(
           Accounts.TeamIdentity |> Ash.Query.filter(handle == ^handle),
           authorize?: false
         ) do
      {:ok, nil} ->
        Accounts.TeamIdentity
        |> Ash.Changeset.for_create(
          :register_with_password,
          %{
            handle: handle,
            name: name,
            role_kind: role_kind,
            facility_id: facility.id,
            password: @demo_password
          },
          authorize?: false
        )
        |> Ash.create!(authorize?: false)

      {:ok, _existing} ->
        :ok
    end
  end

  defp find_or_create_relative do
    case Ash.read_one(
           Accounts.User |> Ash.Query.filter(email == ^@relative_email),
           authorize?: false
         ) do
      {:ok, nil} ->
        user =
          Accounts.User
          |> Ash.Changeset.for_create(
            :register_with_password,
            %{
              email: @relative_email,
              name: "Demo",
              family_name: "Relative",
              password: @demo_password,
              password_confirmation: @demo_password
            },
            authorize?: false
          )
          |> Ash.create!(authorize?: false)

        user
        |> Ash.Changeset.for_update(:update_profile, %{}, authorize?: false)
        |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
        |> Ash.update!(authorize?: false)

      {:ok, existing} ->
        existing
    end
  end

  defp find_or_create_membership(relative, facility) do
    case Ash.read_one(
           Org.FacilityMembership
           |> Ash.Query.filter(user_id == ^relative.id and facility_id == ^facility.id),
           authorize?: false
         ) do
      {:ok, nil} ->
        Ash.create!(
          Org.FacilityMembership,
          %{
            facility_id: facility.id,
            user_id: relative.id,
            role: :relative,
            source: :manual
          },
          authorize?: false
        )

      {:ok, _existing} ->
        :ok
    end
  end

  defp find_or_create(query, resource, attrs) do
    case Ash.read_one(query, authorize?: false) do
      {:ok, nil} -> Ash.create!(resource, attrs, authorize?: false)
      {:ok, existing} -> existing
    end
  end
end
