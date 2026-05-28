defmodule CaredeckWeb.Kitchen.DietProfileTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Kitchen, Org, People}

  require Ash.Query

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "DP #{suffix}", slug: "dp-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "DP Home", slug: "dp-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    care_team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-care-dp-#{suffix}",
          name: "Team Care",
          role_kind: :care,
          facility_id: facility.id,
          password: "phase8-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    resident =
      People.Resident
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, first_name: "Anna", last_name: "Becker"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    %{facility: facility, care_team: care_team, resident: resident, suffix: suffix}
  end

  test "team :care saves a diet profile with allergens + skip_categories", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, view, _html} = live(conn, ~p"/residents/#{ctx.resident.id}/diet")

    view
    |> form("form", %{
      "allergens" => "nuts, lactose",
      "preferences" => "vegetarian",
      "skip_categories" => ["snack"],
      "notes" => "watch sodium"
    })
    |> render_submit()

    profile =
      Kitchen.ResidentDietProfile
      |> Ash.Query.filter(resident_id == ^ctx.resident.id)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert profile.allergens == ["nuts", "lactose"]
    assert profile.preferences == ["vegetarian"]
    assert profile.skip_categories == [:snack]
    assert profile.notes == "watch sodium"
  end

  test "saving twice upserts the same row (no duplicate)", ctx do
    conn = sign_in_team(ctx.conn, ctx.care_team)
    {:ok, view, _html} = live(conn, ~p"/residents/#{ctx.resident.id}/diet")

    view
    |> form("form", %{"allergens" => "gluten", "preferences" => "", "notes" => ""})
    |> render_submit()

    view
    |> form("form", %{"allergens" => "shellfish", "preferences" => "", "notes" => ""})
    |> render_submit()

    rows =
      Kitchen.ResidentDietProfile
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)

    assert length(rows) == 1
    assert hd(rows).allergens == ["shellfish"]
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end
end
