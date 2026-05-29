defmodule CaredeckWeb.AudioCaptureTest do
  use CaredeckWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Caredeck.{Accounts, Feed, Org, People}

  setup do
    Application.put_env(:caredeck, :thumbnailer_mode, :off)
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "AC #{suffix}", slug: "ac-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "AC Home", slug: "ac-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-ac-#{suffix}",
          name: "Team AC",
          role_kind: :care,
          facility_id: facility.id,
          password: "phase7-test-pass"
        },
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    resident =
      People.Resident
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility.id, first_name: "Anna", last_name: "Smith"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    %{facility: facility, team: team, resident: resident}
  end

  test "uploading an audio_notes entry + submit creates an Attachment of kind :audio", ctx do
    audio_bytes = <<0::size(2000)-unit(8)>>

    conn = sign_in_team(ctx.conn, ctx.team)
    {:ok, view, _html} = live(conn, ~p"/feed/compose")

    upload =
      file_input(view, "form", :audio_notes, [
        %{name: "voice-test.webm", content: audio_bytes, type: "audio/webm"}
      ])

    render_upload(upload, "voice-test.webm")

    view
    |> element("#audio-recorder")
    |> render_hook("audio_recorded", %{"duration_sec" => 7})

    view
    |> form("#compose-form", %{"body" => "Voice note attached"})
    |> render_submit()

    audios =
      Feed.Attachment
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)
      |> Enum.filter(&(&1.kind == :audio))

    assert [audio] = audios
    assert audio.mime_type == "audio/webm"
    assert audio.duration_sec == 7
    assert audio.position == 99
    assert String.starts_with?(audio.s3_key, "audios/")
  end

  test "discard_audio clears the pending upload entry", ctx do
    audio_bytes = <<0::size(1000)-unit(8)>>
    conn = sign_in_team(ctx.conn, ctx.team)
    {:ok, view, _html} = live(conn, ~p"/feed/compose")

    upload =
      file_input(view, "form", :audio_notes, [
        %{name: "voice-discard.webm", content: audio_bytes, type: "audio/webm"}
      ])

    render_upload(upload, "voice-discard.webm")
    view |> element("#audio-recorder [data-role=discard]") |> render_click()

    view
    |> form("#compose-form", %{"body" => "Nothing attached"})
    |> render_submit()

    audios =
      Feed.Attachment
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)
      |> Enum.filter(&(&1.kind == :audio))

    assert audios == []
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end
end
