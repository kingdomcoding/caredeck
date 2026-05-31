defmodule Caredeck.Release.Assets do
  alias Caredeck.Feed.S3

  @groups %{
    avatars_team: "images/seed/avatars/team_*.jpg",
    avatars_resident: "images/seed/avatars/resident_*.jpg",
    avatars_relative: "images/seed/avatars/relative_*.jpg",
    avatars_caregiver: "images/seed/avatars/caregiver_*.jpg",
    feed_physio: "images/seed/feed/physio_*.jpg",
    feed_painting: "images/seed/feed/painting_*.jpg",
    feed_handmotor: "images/seed/feed/handmotor_*.jpg",
    feed_birthday: "images/seed/feed/birthday_*.jpg",
    feed_music: "images/seed/feed/music_*.jpg",
    feed_market: "images/seed/feed/market_*.jpg",
    feed_spargel: "images/seed/feed/spargel_*.jpg",
    feed_welcome: "images/seed/feed/welcome_*.jpg",
    feed_doctor: "images/seed/feed/doctor_*.jpg",
    feed_school: "images/seed/feed/school_*.jpg",
    feed_garden: "images/seed/feed/garden_*.jpg",
    videos: "videos/seed/video_*.mp4",
    audio: "audio/seed/audio_*.mp3",
    facility: "images/seed/facility/*.jpg",
    documents: "documents/seed/*.pdf"
  }

  def list(group) do
    pattern = Map.fetch!(@groups, group)
    Path.wildcard(Path.join(seed_root(), pattern)) |> Enum.sort()
  end

  def at(group, idx) do
    files = list(group)
    Enum.at(files, rem(idx, length(files)))
  end

  def seed_root, do: Application.app_dir(:caredeck, "priv/static")

  def upload!(path) do
    key = key_for(path)

    case S3.get_object(key) do
      {:ok, _} ->
        key

      _ ->
        body = read_with_strip(path)
        {:ok, _} = S3.put_object(key, body, content_type(path))
        key
    end
  end

  defp read_with_strip(path) do
    ext = Path.extname(path) |> String.downcase()

    if ext in [".jpg", ".jpeg", ".png"] do
      strip_exif(path)
    else
      {:ok, body} = File.read(path)
      body
    end
  end

  defp strip_exif(path) do
    tmp = Path.join(System.tmp_dir!(), "caredeck_strip_" <> Path.basename(path))

    case System.cmd("mogrify", ["-strip", "-write", tmp, path], stderr_to_stdout: true) do
      {_, 0} ->
        {:ok, body} = File.read(tmp)
        File.rm(tmp)
        body

      _ ->
        {:ok, body} = File.read(path)
        body
    end
  end

  def upload_with_meta!(path) do
    key = upload!(path)
    bytes = File.stat!(path).size

    %{
      s3_key: key,
      bytes: bytes,
      mime_type: content_type(path),
      width: image_width(path),
      height: image_height(path),
      duration_sec: duration(path)
    }
  end

  def video_poster_path(video_path) do
    String.replace_suffix(video_path, ".mp4", "_poster.jpg")
  end

  defp key_for(path) do
    relative = Path.relative_to(path, seed_root())
    "seed/" <> relative
  end

  defp content_type(path) do
    case Path.extname(path) |> String.downcase() do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".mp4" -> "video/mp4"
      ".mp3" -> "audio/mpeg"
      ".pdf" -> "application/pdf"
      _ -> "application/octet-stream"
    end
  end

  defp image_width(path) do
    case Path.extname(path) |> String.downcase() do
      ext when ext in [".jpg", ".jpeg", ".png"] -> ffprobe_int(path, "width")
      _ -> nil
    end
  end

  defp image_height(path) do
    case Path.extname(path) |> String.downcase() do
      ext when ext in [".jpg", ".jpeg", ".png"] -> ffprobe_int(path, "height")
      _ -> nil
    end
  end

  defp duration(path) do
    case Path.extname(path) |> String.downcase() do
      ext when ext in [".mp4", ".mp3"] ->
        case System.cmd(
               "ffprobe",
               [
                 "-v",
                 "error",
                 "-show_entries",
                 "format=duration",
                 "-of",
                 "default=noprint_wrappers=1:nokey=1",
                 path
               ],
               stderr_to_stdout: true
             ) do
          {out, 0} -> out |> String.trim() |> Float.parse() |> elem(0) |> trunc()
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp ffprobe_int(path, field) do
    case System.cmd(
           "ffprobe",
           [
             "-v",
             "error",
             "-select_streams",
             "v:0",
             "-show_entries",
             "stream=" <> field,
             "-of",
             "default=noprint_wrappers=1:nokey=1",
             path
           ],
           stderr_to_stdout: true
         ) do
      {out, 0} ->
        case Integer.parse(String.trim(out)) do
          {n, _} -> n
          _ -> nil
        end

      _ ->
        nil
    end
  rescue
    _ -> nil
  end
end
