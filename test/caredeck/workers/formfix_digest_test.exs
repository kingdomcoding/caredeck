defmodule Caredeck.Workers.FormfixDigestTest do
  use Caredeck.DataCase, async: false

  import Swoosh.TestAssertions

  alias Caredeck.{Accounts, Formfix, Org, People}
  alias Caredeck.Workers.FormfixDigest

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "Dg #{suffix}", slug: "dg-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility = create_facility(district, "Dg Home", "dg-home-#{suffix}")
    admin = create_team(facility, "team-admin-dg-#{suffix}", :admin)
    care = create_team(facility, "team-care-dg-#{suffix}", :care)

    res1 = create_resident(facility, "Anne", "Smith")
    res2 = create_resident(facility, "Bob", "Jones")

    app_draft = Formfix.Applications.start_for_resident!(facility, res1, care)

    app_approved =
      Formfix.Applications.start_for_resident!(facility, res2, care)
      |> mark_ready_to_submit!(facility)
      |> submit!(facility)
      |> approve!(facility)

    %{
      facility: facility,
      admin: admin,
      app_draft: app_draft,
      app_approved: app_approved
    }
  end

  test "delivers digest with every resident and celebration line for approved", ctx do
    assert :ok =
             FormfixDigest.perform(%Oban.Job{
               args: %{"facility_id" => ctx.facility.id}
             })

    assert_email_sent(fn email ->
      assert email.subject =~ "Status update"
      assert email.html_body =~ "Anne Smith"
      assert email.html_body =~ "Bob Jones"
      assert email.html_body =~ "successfully approved!"
      assert email.html_body =~ "Bob Jones"
    end)
  end

  test "delivers nothing when no admins exist in target facility" do
    suffix = :erlang.unique_integer([:positive])

    other_district =
      Caredeck.Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "Empty #{suffix}", slug: "empty-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    empty_facility = create_facility(other_district, "Empty", "empty-#{suffix}")

    assert :ok =
             FormfixDigest.perform(%Oban.Job{
               args: %{"facility_id" => empty_facility.id}
             })

    assert_no_email_sent()
  end

  test "html body includes a note when one exists", ctx do
    {:ok, _} =
      Formfix.ApplicationNote
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: ctx.facility.id,
          application_id: ctx.app_draft.id,
          author_team_id: ctx.admin.id,
          body: "Pinged the relative yesterday."
        },
        tenant: ctx.facility.id,
        actor: ctx.admin
      )
      |> Ash.create(tenant: ctx.facility.id, actor: ctx.admin)

    :ok =
      FormfixDigest.perform(%Oban.Job{
        args: %{"facility_id" => ctx.facility.id}
      })

    assert_email_sent(fn email ->
      assert email.html_body =~ "Pinged the relative yesterday"
    end)
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

  defp mark_ready_to_submit!(app, facility) do
    app
    |> Ash.Changeset.for_update(:mark_ready_to_submit, %{},
      tenant: facility.id,
      authorize?: false
    )
    |> Ash.update!(tenant: facility.id, authorize?: false)
  end

  defp submit!(app, facility) do
    app
    |> Ash.Changeset.for_update(:submit, %{}, tenant: facility.id, authorize?: false)
    |> Ash.update!(tenant: facility.id, authorize?: false)
  end

  defp approve!(app, facility) do
    app
    |> Ash.Changeset.for_update(:approve, %{outcome: "ok"},
      tenant: facility.id,
      authorize?: false
    )
    |> Ash.update!(tenant: facility.id, authorize?: false)
  end
end
