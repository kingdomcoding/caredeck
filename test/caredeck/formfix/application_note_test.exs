defmodule Caredeck.Formfix.ApplicationNoteTest do
  use Caredeck.DataCase, async: false

  alias Caredeck.Accounts
  alias Caredeck.Formfix.{Application, ApplicationNote}
  alias Caredeck.{Org, People}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "Note #{suffix}", slug: "note-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    fac_a = create_facility(district, "A", "note-a-#{suffix}")
    fac_b = create_facility(district, "B", "note-b-#{suffix}")

    admin_a = create_team(fac_a, "team-admin-a-#{suffix}", :admin)
    admin_a2 = create_team(fac_a, "team-admin-a2-#{suffix}", :admin)
    admin_b = create_team(fac_b, "team-admin-b-#{suffix}", :admin)
    care_a = create_team(fac_a, "team-care-a-#{suffix}", :care)

    resident = create_resident(fac_a, "Anne", "Smith")

    app =
      Application
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: fac_a.id, resident_id: resident.id},
        tenant: fac_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: fac_a.id, authorize?: false)

    %{
      facility_a: fac_a,
      facility_b: fac_b,
      admin_a: admin_a,
      admin_a2: admin_a2,
      admin_b: admin_b,
      care_a: care_a,
      app: app
    }
  end

  test "admin can create a note on their facility's application", ctx do
    {:ok, note} =
      ApplicationNote
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: ctx.facility_a.id,
          application_id: ctx.app.id,
          author_team_id: ctx.admin_a.id,
          body: "Looks good."
        },
        tenant: ctx.facility_a.id,
        actor: ctx.admin_a
      )
      |> Ash.create(tenant: ctx.facility_a.id, actor: ctx.admin_a)

    assert note.body == "Looks good."
    assert note.author_team_id == ctx.admin_a.id
  end

  test "care-role team cannot create a note", ctx do
    result =
      ApplicationNote
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: ctx.facility_a.id,
          application_id: ctx.app.id,
          author_team_id: ctx.care_a.id,
          body: "no"
        },
        tenant: ctx.facility_a.id,
        actor: ctx.care_a
      )
      |> Ash.create(tenant: ctx.facility_a.id, actor: ctx.care_a)

    assert {:error, %Ash.Error.Forbidden{}} = result
  end

  test "cross-facility read returns 0 rows", ctx do
    {:ok, _} =
      ApplicationNote
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: ctx.facility_a.id,
          application_id: ctx.app.id,
          author_team_id: ctx.admin_a.id,
          body: "from A"
        },
        tenant: ctx.facility_a.id,
        actor: ctx.admin_a
      )
      |> Ash.create(tenant: ctx.facility_a.id, actor: ctx.admin_a)

    rows =
      ApplicationNote
      |> Ash.read!(tenant: ctx.facility_b.id, actor: ctx.admin_b)

    assert rows == []
  end

  test "only the author admin can destroy a note", ctx do
    {:ok, note} =
      ApplicationNote
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: ctx.facility_a.id,
          application_id: ctx.app.id,
          author_team_id: ctx.admin_a.id,
          body: "mine"
        },
        tenant: ctx.facility_a.id,
        actor: ctx.admin_a
      )
      |> Ash.create(tenant: ctx.facility_a.id, actor: ctx.admin_a)

    other_admin_attempt =
      note
      |> Ash.Changeset.for_destroy(:destroy, %{}, tenant: ctx.facility_a.id, actor: ctx.admin_a2)
      |> Ash.destroy(tenant: ctx.facility_a.id, actor: ctx.admin_a2)

    assert {:error, %Ash.Error.Forbidden{}} = other_admin_attempt

    assert :ok ==
             note
             |> Ash.Changeset.for_destroy(:destroy, %{}, tenant: ctx.facility_a.id, actor: ctx.admin_a)
             |> Ash.destroy(tenant: ctx.facility_a.id, actor: ctx.admin_a)
  end

  test "body over 2000 chars fails validation", ctx do
    too_long = String.duplicate("x", 2001)

    result =
      ApplicationNote
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: ctx.facility_a.id,
          application_id: ctx.app.id,
          author_team_id: ctx.admin_a.id,
          body: too_long
        },
        tenant: ctx.facility_a.id,
        actor: ctx.admin_a
      )
      |> Ash.create(tenant: ctx.facility_a.id, actor: ctx.admin_a)

    assert {:error, %Ash.Error.Invalid{}} = result
  end

  test "empty body fails validation", ctx do
    result =
      ApplicationNote
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: ctx.facility_a.id,
          application_id: ctx.app.id,
          author_team_id: ctx.admin_a.id,
          body: ""
        },
        tenant: ctx.facility_a.id,
        actor: ctx.admin_a
      )
      |> Ash.create(tenant: ctx.facility_a.id, actor: ctx.admin_a)

    assert {:error, %Ash.Error.Invalid{}} = result
  end

  defp create_facility(d, name, slug) do
    Org.Facility
    |> Ash.Changeset.for_create(
      :create,
      %{district_id: d.id, name: name, slug: slug},
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  defp create_team(fac, handle, role_kind) do
    Accounts.TeamIdentity
    |> Ash.Changeset.for_create(
      :register_with_password,
      %{
        handle: handle,
        name: "T #{handle}",
        role_kind: role_kind,
        facility_id: fac.id,
        password: "phase11-test-pass"
      },
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  defp create_resident(f, first, last) do
    People.Resident
    |> Ash.Changeset.for_create(
      :create,
      %{facility_id: f.id, first_name: first, last_name: last},
      tenant: f.id,
      authorize?: false
    )
    |> Ash.create!(tenant: f.id, authorize?: false)
  end
end
