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
    attachment_match?(key, facility_id) or relative_avatar_match?(key, facility_id) or
      caregiver_avatar_match?(key, facility_id)
  end

  defp attachment_match?(key, facility_id) do
    Caredeck.Feed.Attachment
    |> Ash.Query.filter(s3_key == ^key or thumbnail_s3_key == ^key)
    |> Ash.read_one(tenant: facility_id, authorize?: false)
    |> case do
      {:ok, %{}} -> true
      _ -> false
    end
  end

  defp relative_avatar_match?(key, facility_id) do
    Caredeck.People.Relative
    |> Ash.Query.filter(avatar_url == ^key)
    |> Ash.read_one(tenant: facility_id, authorize?: false)
    |> case do
      {:ok, %{}} -> true
      _ -> false
    end
  end

  defp caregiver_avatar_match?(key, facility_id) do
    Caredeck.People.CaregiverProfile
    |> Ash.Query.filter(avatar_url == ^key)
    |> Ash.read_one(tenant: facility_id, authorize?: false)
    |> case do
      {:ok, %{}} -> true
      _ -> false
    end
  end
end

# NOTE: Authz is centralised in the LoadCurrentFacility plug (already proves the
# requester is a member of `facility.id`). Looking up the row tenant-scoped is
# sufficient — running the Attachment policy here would also need to load the
# parent post via Ash, which is an extra query for no security gain.
