defmodule CaredeckWeb.AttachmentController do
  use CaredeckWeb, :controller

  require Ash.Query

  def show(conn, %{"key" => key_parts}) do
    key = Enum.join(key_parts, "/")
    facility = conn.assigns[:current_facility]

    cond do
      is_nil(facility) ->
        conn |> put_status(:unauthorized) |> text("Sign in required.")

      not attachment_in_facility?(key, facility.id) ->
        conn |> put_status(:not_found) |> text("Not found.")

      true ->
        case Caredeck.Feed.S3.get_object(key) do
          {:ok, %{body: body, headers: headers}} ->
            content_type =
              Enum.find_value(headers, "application/octet-stream", fn
                {"Content-Type", v} -> v
                {"content-type", v} -> v
                _ -> nil
              end)

            conn
            |> put_resp_header("cache-control", "private, max-age=300")
            |> put_resp_content_type(content_type)
            |> send_resp(200, body)

          _ ->
            conn |> put_status(:not_found) |> text("Not found.")
        end
    end
  end

  defp attachment_in_facility?(key, facility_id) do
    query =
      Caredeck.Feed.Attachment
      |> Ash.Query.filter(s3_key == ^key or thumbnail_s3_key == ^key)

    case Ash.read_one(query, tenant: facility_id, authorize?: false) do
      {:ok, %{}} -> true
      _ -> false
    end
  end
end
