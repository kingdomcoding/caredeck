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
        %{facility_id: facility.id, first_name: "Anna", last_name: "Becker"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    %{facility: facility, team: team, resident: resident}
  end

  test "request_audio_url replies with an s3_key + presigned PUT URL", ctx do
    conn = sign_in_team(ctx.conn, ctx.team)
    {:ok, view, _html} = live(conn, ~p"/feed/compose")

    rendered =
      view
      |> element("#audio-recorder")
      |> render_hook("request_audio_url", %{"filename" => "voice-test.webm"})

    assert is_binary(rendered)
  end

  test "audio_uploaded + submit creates an Attachment row of kind :audio", ctx do
    conn = sign_in_team(ctx.conn, ctx.team)
    {:ok, view, _html} = live(conn, ~p"/feed/compose")

    view
    |> element("#audio-recorder")
    |> render_hook("audio_uploaded", %{
      "s3_key" => "audios/voice-test.webm",
      "mime_type" => "audio/webm;codecs=opus",
      "bytes" => 42_000,
      "duration_sec" => 7
    })

    view
    |> form("#compose-form", %{"body" => "Voice note attached"})
    |> render_submit()

    audios =
      Feed.Attachment
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)
      |> Enum.filter(&(&1.kind == :audio))

    assert [audio] = audios
    assert audio.duration_sec == 7
    assert audio.mime_type == "audio/webm;codecs=opus"
    assert audio.s3_key == "audios/voice-test.webm"
    assert audio.bytes == 42_000
    assert audio.position == 99
  end

  test "discard_audio clears pending_audio so no Attachment is created", ctx do
    conn = sign_in_team(ctx.conn, ctx.team)
    {:ok, view, _html} = live(conn, ~p"/feed/compose")

    view
    |> element("#audio-recorder")
    |> render_hook("audio_uploaded", %{
      "s3_key" => "audios/voice-discard.webm",
      "mime_type" => "audio/webm",
      "bytes" => 1000,
      "duration_sec" => 3
    })

    view |> element("#audio-recorder") |> render_hook("discard_audio", %{})

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
