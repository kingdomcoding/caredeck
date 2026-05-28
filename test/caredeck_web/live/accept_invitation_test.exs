defmodule CaredeckWeb.AcceptInvitationTest do
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
        %{name: "AI #{suffix}", slug: "ai-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "AI Home", slug: "ai-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    inviter = create_user("inviter-#{suffix}@example.test")
    create_membership(inviter, facility)

    resident =
      People.Resident
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, first_name: "Anna", last_name: "Becker"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    %{
      facility: facility,
      inviter: inviter,
      resident: resident,
      suffix: suffix
    }
  end

  test "tampered token redirects to /sign-in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/invitations/garbage")
  end

  test "valid token renders the registration form for a new email", ctx do
    inv = create_invitation(ctx.facility, ctx.inviter, ctx.resident, "newbie-#{ctx.suffix}@example.test", :daughter)

    {:ok, _view, html} = live(ctx.conn, ~p"/invitations/#{inv.token}")
    assert html =~ "Anna Becker"
    assert html =~ "Join Caredeck"
    assert html =~ "newbie-#{ctx.suffix}@example.test"
  end

  test "accept flow creates User + Relative + Membership + RelativeOfResident", ctx do
    email = "newbie2-#{ctx.suffix}@example.test"
    inv = create_invitation(ctx.facility, ctx.inviter, ctx.resident, email, :son)

    {:ok, view, _html} = live(ctx.conn, ~p"/invitations/#{inv.token}")

    {:error, {:redirect, %{to: "/sign-in"}}} =
      view
      |> form("form[phx-submit=accept]", %{
        "first_name" => "John",
        "family_name" => "Doe",
        "password" => "phase5-test-pass",
        "phone" => "555-0100",
        "relationship" => "son"
      })
      |> render_submit()

    user = find_user(email)
    assert user

    relative =
      People.Relative
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert relative.display_name == "John Doe"

    membership =
      Org.FacilityMembership
      |> Ash.Query.filter(user_id == ^user.id and facility_id == ^ctx.facility.id)
      |> Ash.read_one!(authorize?: false)

    assert membership.role == :relative
    assert membership.source == :invited

    link =
      People.RelativeOfResident
      |> Ash.Query.filter(relative_id == ^relative.id and resident_id == ^ctx.resident.id)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert link.relationship == :son

    reloaded =
      Ash.get!(RelativeInvitation, inv.id, tenant: ctx.facility.id, authorize?: false)

    assert reloaded.accepted_at != nil
  end

  test "existing-user accept re-uses the user + adds RelativeOfResident", ctx do
    email = "existing-#{ctx.suffix}@example.test"
    existing_user = create_user(email)
    create_membership(existing_user, ctx.facility)

    existing_relative =
      People.Relative
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: ctx.facility.id, user_id: existing_user.id, display_name: "Already Here"},
        tenant: ctx.facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: ctx.facility.id, authorize?: false)

    inv = create_invitation(ctx.facility, ctx.inviter, ctx.resident, email, :niece)

    {:ok, view, html} = live(ctx.conn, ~p"/invitations/#{inv.token}")
    assert html =~ "You already have a Caredeck account"

    {:error, {:redirect, %{to: "/sign-in"}}} =
      view
      |> form("form[phx-submit=accept]", %{"relationship" => "niece"})
      |> render_submit()

    link =
      People.RelativeOfResident
      |> Ash.Query.filter(relative_id == ^existing_relative.id and resident_id == ^ctx.resident.id)
      |> Ash.read_one!(tenant: ctx.facility.id, authorize?: false)

    assert link.relationship == :niece
  end

  test "already-accepted invitation redirects with flash", ctx do
    email = "redo-#{ctx.suffix}@example.test"
    inv = create_invitation(ctx.facility, ctx.inviter, ctx.resident, email, :son)

    inv
    |> Ash.Changeset.for_update(:accept, %{},
      tenant: ctx.facility.id,
      authorize?: false
    )
    |> Ash.update!(tenant: ctx.facility.id, authorize?: false)

    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(ctx.conn, ~p"/invitations/#{inv.token}")
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

  defp create_invitation(facility, inviter, resident, email, relationship) do
    RelativeInvitation
    |> Ash.Changeset.for_create(
      :create,
      %{
        facility_id: facility.id,
        inviter_user_id: inviter.id,
        resident_id: resident.id,
        email: email,
        suggested_relationship: relationship
      },
      tenant: facility.id,
      actor: inviter
    )
    |> Ash.create!(tenant: facility.id, actor: inviter)
  end

  defp find_user(email) do
    case Ash.read_one(
           Accounts.User |> Ash.Query.filter(email == ^email),
           authorize?: false
         ) do
      {:ok, %{} = u} -> u
      _ -> nil
    end
  end
end
