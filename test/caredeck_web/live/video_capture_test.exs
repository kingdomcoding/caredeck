defmodule CaredeckWeb.VideoCaptureTest do
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
        %{name: "VC #{suffix}", slug: "vc-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility =
      Org.Facility
      |> Ash.Changeset.for_create(
        :create,
        %{district_id: district.id, name: "VC Home", slug: "vc-home-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    team =
      Accounts.TeamIdentity
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          handle: "team-vc-#{suffix}",
          name: "Team VC",
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
        %{facility_id: facility.id, first_name: "Hans", last_name: "Klein"},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    %{facility: facility, team: team, resident: resident}
  end

  test "uploading a video + submit creates an Attachment of kind :video", ctx do
    video_bytes = <<0::size(5000)-unit(8)>>

    conn = sign_in_team(ctx.conn, ctx.team)
    {:ok, view, _html} = live(conn, ~p"/feed/compose")

    upload =
      file_input(view, "form", :videos, [
        %{name: "clip.mp4", content: video_bytes, type: "video/mp4"}
      ])

    render_upload(upload, "clip.mp4")

    view
    |> form("#compose-form", %{"body" => "Watch this"})
    |> render_submit()

    videos =
      Feed.Attachment
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)
      |> Enum.filter(&(&1.kind == :video))

    assert [video] = videos
    assert video.mime_type == "video/mp4"
    assert video.position == 50
    assert String.starts_with?(video.s3_key, "videos/")
  end

  test "cancel_video drops the queued upload entry", ctx do
    video_bytes = <<0::size(3000)-unit(8)>>
    conn = sign_in_team(ctx.conn, ctx.team)
    {:ok, view, _html} = live(conn, ~p"/feed/compose")

    upload =
      file_input(view, "form", :videos, [
        %{name: "drop.mp4", content: video_bytes, type: "video/mp4"}
      ])

    render_upload(upload, "drop.mp4")

    html = render(view)
    [_, ref] = Regex.run(~r/phx-value-ref="([^"]+)"/, html)

    view
    |> element("button[phx-click=cancel_video][phx-value-ref='#{ref}']")
    |> render_click()

    view
    |> form("#compose-form", %{"body" => "Nothing attached"})
    |> render_submit()

    videos =
      Feed.Attachment
      |> Ash.read!(tenant: ctx.facility.id, authorize?: false)
      |> Enum.filter(&(&1.kind == :video))

    assert videos == []
  end

  defp sign_in_team(conn, team) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(team)
  end
end
