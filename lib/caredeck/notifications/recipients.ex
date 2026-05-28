defmodule Caredeck.Notifications.Recipients do
  require Ash.Query

  alias Caredeck.{Feed, People}

  def for_post(post_id, facility_id) do
    post =
      Feed.Post
      |> Ash.get!(post_id,
        tenant: facility_id,
        authorize?: false,
        load: [audience: [relative_links: [:relative]], attachments: []]
      )

    user_ids =
      post.audience
      |> Enum.flat_map(& &1.relative_links)
      |> Enum.map(& &1.relative.user_id)
      |> Enum.uniq()

    {post, user_ids}
  end

  def for_resident(resident_id, facility_id) do
    People.RelativeOfResident
    |> Ash.Query.filter(resident_id == ^resident_id)
    |> Ash.Query.load(:relative)
    |> Ash.read!(tenant: facility_id, authorize?: false)
    |> Enum.map(& &1.relative.user_id)
    |> Enum.uniq()
  end
end
