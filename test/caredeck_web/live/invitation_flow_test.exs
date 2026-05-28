defmodule CaredeckWeb.InvitationFlowTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  require Ash.Query

  alias Caredeck.{Accounts, Org, People}
  alias Caredeck.People.RelativeInvitation

  setup do
    Application.put_env(:caredeck, :thumbnailer_mode, :off)
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "IF #{suffix}", slug: "if-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "IF Home", slug: "if-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    inviter_user = create_user("if-inviter-#{suffix}@example.test")
    create_membership(inviter_user, facility)
    inviter_relative = create_relative(facility, inviter_user, "Inviter R")

    resident =
      People.Resident
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, first_name: "Marianne", last_name: "Schmidt"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    link_relative(facility, inviter_relative, resident, :daughter)

    %{
      facility: facility,
      inviter_user: inviter_user,
      inviter_relative: inviter_relative,
      resident: resident,
      suffix: suffix
    }
  end

  test "end-to-end: invite → accept → both relatives visible on /residents/:id", ctx do
    invitee_email = "if-invitee-#{ctx.suffix}@example.test"

    # Step 1 — inviter creates invitation via the LiveView
    conn = ctx.conn |> sign_in_user(ctx.inviter_user)
    {:ok, view, _html} = live(conn, ~p"/residents/#{ctx.resident.id}/invite")

    view
    |> form("form[phx-submit=send]", %{"email" => invitee_email, "relationship" => "son"})
    |> render_submit()

    # Step 2 — fetch the invitation's token
    inv =
      RelativeInvitation
      |> Ash.Query.filter(email == ^invitee_email)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert inv.token

    # Step 3 — recipient (anonymous) opens the invitation link
    {:ok, view2, _html} = live(build_conn(), ~p"/invitations/#{inv.token}")

    # Step 4 — recipient submits the accept form
    {:error, {:redirect, %{to: "/sign-in"}}} =
      view2
      |> form("form[phx-submit=accept]", %{
        "first_name" => "Sonny",
        "family_name" => "Schmidt",
        "password" => "phase5-test-pass",
        "phone" => "",
        "relationship" => "son"
      })
      |> render_submit()

    # Step 5 — assert all 4 rows exist
    user =
      Accounts.User
      |> Ash.Query.filter(email == ^invitee_email)
      |> Ash.read_one!(authorize?: false)

    relative =
      People.Relative
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    membership =
      Org.FacilityMembership
      |> Ash.Query.filter(user_id == ^user.id and facility_id == ^ctx.facility.id)
      |> Ash.read_one!(authorize?: false)

    link =
      People.RelativeOfResident
      |> Ash.Query.filter(relative_id == ^relative.id and resident_id == ^ctx.resident.id)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    reloaded_invitation =
      Ash.get!(RelativeInvitation, inv.id, tenant: ctx.facility.id, authorize?: false)

    assert relative.display_name == "Sonny Schmidt"
    assert membership.role == :relative
    assert membership.source == :invited
    assert link.relationship == :son
    assert reloaded_invitation.accepted_at != nil

    # Step 6 — inviter navigates to ProfileLive and sees both relatives in the graph
    inviter_conn = build_conn() |> sign_in_user(ctx.inviter_user)
    {:ok, _view, html} = live(inviter_conn, ~p"/residents/#{ctx.resident.id}")
    assert html =~ "Inviter R"
    assert html =~ "Sonny Schmidt"
    assert html =~ "Daughter"
    assert html =~ "Son"
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
