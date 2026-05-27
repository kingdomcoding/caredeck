alias Caredeck.Accounts
alias Caredeck.Org

require Ash.Query

defmodule SeedHelpers do
  def find_or_create(query, resource, attrs) do
    case Ash.read_one(query, authorize?: false) do
      {:ok, nil} -> Ash.create!(resource, attrs, authorize?: false)
      {:ok, existing} -> existing
    end
  end
end

district =
  SeedHelpers.find_or_create(
    Org.District |> Ash.Query.filter(slug == "sandbox"),
    Org.District,
    %{name: "Sandbox District", slug: "sandbox"}
  )

facility =
  SeedHelpers.find_or_create(
    Org.Facility |> Ash.Query.filter(slug == "sandbox-home"),
    Org.Facility,
    %{district_id: district.id, name: "Sandbox Care Home", slug: "sandbox-home"}
  )

SeedHelpers.find_or_create(
  Org.Ward |> Ash.Query.filter(facility_id == ^facility.id and name == "Ground Floor"),
  Org.Ward,
  %{facility_id: facility.id, name: "Ground Floor"}
)

team_seeds = [
  %{name: "Team Care", handle: "team-care", role_kind: :care},
  %{name: "Team Activities", handle: "team-activities", role_kind: :activities},
  %{name: "Team Therapy", handle: "team-therapy", role_kind: :therapy}
]

for %{handle: handle, name: name, role_kind: role_kind} <- team_seeds do
  case Ash.read_one(
         Accounts.TeamIdentity |> Ash.Query.filter(handle == ^handle),
         authorize?: false
       ) do
    {:ok, nil} ->
      AshAuthentication.Strategy.Password.Actions.register(
        AshAuthentication.Info.strategy!(Accounts.TeamIdentity, :password),
        %{
          handle: handle,
          name: name,
          role_kind: role_kind,
          facility_id: facility.id,
          password: "phase1-demo-pass",
          password_confirmation: "phase1-demo-pass"
        },
        []
      )

    {:ok, _existing} ->
      :ok
  end
end

relative_email = "demo-relative@example.test"

relative =
  case Ash.read_one(
         Accounts.User |> Ash.Query.filter(email == ^relative_email),
         authorize?: false
       ) do
    {:ok, nil} ->
      {:ok, user} =
        AshAuthentication.Strategy.Password.Actions.register(
          AshAuthentication.Info.strategy!(Accounts.User, :password),
          %{
            email: relative_email,
            name: "Demo",
            family_name: "Relative",
            password: "phase1-demo-pass",
            password_confirmation: "phase1-demo-pass"
          },
          []
        )

      user
      |> Ash.Changeset.for_update(:update_profile, %{}, authorize?: false)
      |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
      |> Ash.update!(authorize?: false)

    {:ok, existing} ->
      existing
  end

case Ash.read_one(
       Org.FacilityMembership
       |> Ash.Query.filter(user_id == ^relative.id and facility_id == ^facility.id),
       authorize?: false
     ) do
  {:ok, nil} ->
    Ash.create!(
      Org.FacilityMembership,
      %{facility_id: facility.id, user_id: relative.id, role: :relative, source: :manual},
      authorize?: false
    )

  {:ok, _existing} ->
    :ok
end

IO.puts("")
IO.puts("Sandbox facility ready.")
IO.puts("  Relative: #{relative_email} / phase1-demo-pass")
IO.puts("  Teams:    team-care · team-activities · team-therapy / phase1-demo-pass")
IO.puts("")
