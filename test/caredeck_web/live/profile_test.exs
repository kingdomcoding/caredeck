defmodule CaredeckWeb.ProfileTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  require Ash.Query

  alias Caredeck.{Accounts, Org, People}

  setup do
    Application.put_env(:caredeck, :thumbnailer_mode, :off)
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "P #{suffix}", slug: "p-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "P Home", slug: "p-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user_a = create_user("pa-#{suffix}@example.test")
    user_b = create_user("pb-#{suffix}@example.test")
    create_membership(user_a, facility)
    create_membership(user_b, facility)

    relative_a = create_relative(facility, user_a, "Anna Smith")
    relative_b = create_relative(facility, user_b, "Oliver Brooks")

    resident =
      People.Resident
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, first_name: "Marianne", last_name: "Schmidt"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    link_relative(facility, relative_a, resident, :daughter)
    link_relative(facility, relative_b, resident, :son)

    %{
      facility: facility,
      user_a: user_a,
      user_b: user_b,
      relative_a: relative_a,
      relative_b: relative_b,
      resident: resident
    }
  end

  test "ProfileLive shows both relatives with 'Me' on current user", ctx do
    conn = ctx.conn |> sign_in_user(ctx.user_a)
    {:ok, _view, html} = live(conn, ~p"/residents/#{ctx.resident.id}")
    assert html =~ "Anna Smith"
    assert html =~ "Oliver Brooks"
    assert html =~ "Daughter"
    assert html =~ "Son"
    assert html =~ "Me"
  end

  test "ProfileLive caregivers tab shows caregivers", ctx do
    People.CaregiverProfile
    |> Ash.Changeset.for_create(
      :create,
      %{
        facility_id: ctx.facility.id,
        user_id: ctx.user_a.id,
        display_name: "Caregiver Cara",
        role_label: "Lead nurse"
      },
      tenant: ctx.facility.id,
      authorize?: false
    )
    |> Ash.create!(tenant: ctx.facility.id, authorize?: false)

    conn = ctx.conn |> sign_in_user(ctx.user_a)
    {:ok, view, _html} = live(conn, ~p"/residents/#{ctx.resident.id}")

    view |> element("button[phx-click=switch_tab][phx-value-tab=caregivers]") |> render_click()
    rendered = render(view)
    assert rendered =~ "Caregiver Cara"
    assert rendered =~ "Lead nurse"
  end

  test "EditProfileLive saves display_name + phone + relationship", ctx do
    conn = ctx.conn |> sign_in_user(ctx.user_a)
    {:ok, view, _html} = live(conn, ~p"/profile/edit")

    view
    |> form("form[phx-submit=save]", %{
      "first_name" => "Anne",
      "family_name" => "Smith-Watson",
      "phone" => "555-9999",
      "relationship" => "niece"
    })
    |> render_submit()

    reloaded =
      Ash.get!(People.Relative, ctx.relative_a.id,
        tenant: ctx.facility.id,
        actor: ctx.user_a
      )

    assert reloaded.display_name == "Anne Smith-Watson"
    assert reloaded.phone == "555-9999"

    link =
      People.RelativeOfResident
      |> Ash.Query.filter(relative_id == ^ctx.relative_a.id)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert link.relationship == :niece
  end

  defp create_user(email) do
    user =
      Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          email: email,
          name: "Test",
          family_name: "User",
          password: "phase5-test-pass",
          password_confirmation: "phase5-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    user
    |> Ash.Changeset.for_update(:update_profile, %{}, authorize?: false)
    |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
    |> Ash.update!(authorize?: false)
  end

  defp create_membership(user, facility) do
    Org.FacilityMembership
    |> Ash.Changeset.for_create(
      :create,
      %{facility_id: facility.id, user_id: user.id, role: :relative, source: :manual},
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  defp create_relative(facility, user, display_name) do
    People.Relative
    |> Ash.Changeset.for_create(
      :create,
      %{facility_id: facility.id, user_id: user.id, display_name: display_name},
      tenant: facility.id,
      authorize?: false
    )
    |> Ash.create!(tenant: facility.id, authorize?: false)
  end

  defp link_relative(facility, relative, resident, relationship) do
    People.RelativeOfResident
    |> Ash.Changeset.for_create(
      :create,
      %{
        facility_id: facility.id,
        relative_id: relative.id,
        resident_id: resident.id,
        relationship: relationship
      },
      tenant: facility.id,
      authorize?: false
    )
    |> Ash.create!(tenant: facility.id, authorize?: false)
  end

  defp sign_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)
  end
end
