defmodule Caredeck.Release.Seeds do
  alias Caredeck.Accounts
  alias Caredeck.Feed
  alias Caredeck.Org
  alias Caredeck.People
  alias Caredeck.Release.NamePool

  require Ash.Query

  @relative_email "demo-relative@example.test"
  @demo_password "phase1-demo-pass"
  @bulk_password "phase2-bulk-pass"

  @team_seeds [
    %{name: "Team Care", handle: "team-care", role_kind: :care},
    %{name: "Team Activities", handle: "team-activities", role_kind: :activities},
    %{name: "Team Therapy", handle: "team-therapy", role_kind: :therapy}
  ]

  @resident_count 30
  @relative_count_target 80
  @relationship_pool ~w(daughter son niece nephew granddaughter grandson spouse sibling)a

  @demo_post_body "Good news! Mr Hungsinger had a very good report from his physiotherapist today."

  @demo_comments [
    "Wonderful to hear, thank you for the update.",
    "Please pass along our love."
  ]

  @placeholder_jpeg <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
                      0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
                      0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
                      0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
                      0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
                      0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
                      0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
                      0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
                      0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
                      0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
                      0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                      0x09, 0x0A, 0x0B, 0xFF, 0xC4, 0x00, 0xB5, 0x10, 0x00, 0x02, 0x01, 0x03,
                      0x03, 0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04, 0x00, 0x00, 0x01, 0x7D,
                      0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06,
                      0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08,
                      0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0, 0x24, 0x33, 0x62, 0x72,
                      0x82, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, 0xFB,
                      0xD0, 0xFF, 0xD9>>

  def run do
    Application.put_env(:caredeck, :thumbnailer_mode, :sync)

    district = find_or_create_district()
    facility = find_or_create_facility(district)
    primary_ward = find_or_create_primary_ward(facility)
    secondary_ward = find_or_create_secondary_ward(facility)
    Enum.each(@team_seeds, &find_or_create_team(&1, facility))
    relative = find_or_create_relative()
    find_or_create_membership(relative, facility)
    find_or_create_residents(facility, primary_ward, secondary_ward)
    find_or_create_relatives_and_links(facility)
    Feed.S3.ensure_bucket!()
    post = find_or_create_demo_post(facility)

    if post do
      seed_demo_interactions(facility, post)
      seed_demo_attachments(facility, post, 3)
    end

    seed_extra_posts(facility)

    resident_count =
      People.Resident
      |> Ash.read!(tenant: facility.id, authorize?: false)
      |> length()

    relative_count =
      People.Relative
      |> Ash.read!(tenant: facility.id, authorize?: false)
      |> length()

    post_count =
      Feed.Post
      |> Ash.read!(tenant: facility.id, authorize?: false)
      |> length()

    comment_count =
      Feed.Comment
      |> Ash.read!(tenant: facility.id, authorize?: false)
      |> length()

    reaction_count =
      Feed.Reaction
      |> Ash.read!(tenant: facility.id, authorize?: false)
      |> length()

    tag_count =
      Feed.ResidentTagOnPost
      |> Ash.read!(tenant: facility.id, authorize?: false)
      |> length()

    attachment_count =
      Feed.Attachment
      |> Ash.read!(tenant: facility.id, authorize?: false)
      |> length()

    IO.puts("")
    IO.puts("Sandbox facility ready.")
    IO.puts("  Relative: #{@relative_email} / #{@demo_password}")
    IO.puts("  Teams:    team-care · team-activities · team-therapy / #{@demo_password}")
    IO.puts("  Residents:   #{resident_count}")
    IO.puts("  Relatives:   #{relative_count}")
    IO.puts("  Posts:       #{post_count}")
    IO.puts("  Comments:    #{comment_count}")
    IO.puts("  Reactions:   #{reaction_count}")
    IO.puts("  Tags:        #{tag_count}")
    IO.puts("  Attachments: #{attachment_count}")
    IO.puts("")

    :ok
  end

  defp seed_extra_posts(facility) do
    extras = [
      %{
        team: "team-activities",
        body: "Group photo from this week's painting workshop — everyone in great spirits.",
        photo_count: 4,
        audience: 5
      },
      %{
        team: "team-therapy",
        body: "Two short clips from today's hand-motor exercises.",
        photo_count: 2,
        audience: 2
      }
    ]

    Enum.each(extras, &find_or_create_extra_post(facility, &1))
  end

  defp find_or_create_extra_post(facility, %{
         team: handle,
         body: body,
         photo_count: n,
         audience: aud_n
       }) do
    {:ok, team} =
      Ash.read_one(
        Accounts.TeamIdentity |> Ash.Query.filter(handle == ^handle),
        authorize?: false
      )

    existing =
      Feed.Post
      |> Ash.Query.filter(team_identity_id == ^team.id and body == ^body)
      |> Ash.read!(tenant: facility.id, authorize?: false)

    case existing do
      [_ | _] ->
        :ok

      [] ->
        post =
          Feed.Post
          |> Ash.Changeset.for_create(
            :create,
            %{facility_id: facility.id, team_identity_id: team.id, body: body},
            tenant: facility.id,
            authorize?: false
          )
          |> Ash.create!(tenant: facility.id, authorize?: false)

        residents =
          People.Resident
          |> Ash.read!(tenant: facility.id, authorize?: false)
          |> Enum.take(aud_n)

        Enum.each(residents, fn resident ->
          Feed.PostAudience
          |> Ash.Changeset.for_create(
            :create,
            %{facility_id: facility.id, post_id: post.id, resident_id: resident.id},
            tenant: facility.id,
            authorize?: false
          )
          |> Ash.create!(tenant: facility.id, authorize?: false)

          Feed.ResidentTagOnPost
          |> Ash.Changeset.for_create(
            :create,
            %{facility_id: facility.id, post_id: post.id, resident_id: resident.id},
            tenant: facility.id,
            authorize?: false
          )
          |> Ash.create!(tenant: facility.id, authorize?: false)
        end)

        seed_demo_attachments(facility, post, n)
    end
  end

  defp seed_demo_attachments(facility, post, count) do
    existing =
      Feed.Attachment
      |> Ash.Query.filter(post_id == ^post.id)
      |> Ash.read!(tenant: facility.id, authorize?: false)

    if existing == [] do
      for i <- 0..(count - 1) do
        key = Feed.S3.generate_key("photos", "seed-#{post.id}-#{i}.jpg")
        {:ok, _} = Feed.S3.put_object(key, @placeholder_jpeg, "image/jpeg")

        Feed.Attachment
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: facility.id,
            post_id: post.id,
            kind: :photo,
            s3_key: key,
            mime_type: "image/jpeg",
            bytes: byte_size(@placeholder_jpeg),
            position: i
          },
          tenant: facility.id,
          authorize?: false
        )
        |> Ash.create!(tenant: facility.id, authorize?: false)
      end
    end
  end

  defp find_or_create_demo_post(facility) do
    {:ok, team_care} =
      Ash.read_one(
        Accounts.TeamIdentity |> Ash.Query.filter(handle == "team-care"),
        authorize?: false
      )

    existing =
      Feed.Post
      |> Ash.Query.filter(team_identity_id == ^team_care.id and body == ^@demo_post_body)
      |> Ash.read!(tenant: facility.id, authorize?: false)

    case existing do
      [post | _] ->
        post

      [] ->
        post =
          Feed.Post
          |> Ash.Changeset.for_create(
            :create,
            %{
              facility_id: facility.id,
              team_identity_id: team_care.id,
              body: @demo_post_body
            },
            tenant: facility.id,
            authorize?: false
          )
          |> Ash.create!(tenant: facility.id, authorize?: false)

        audience =
          People.Resident
          |> Ash.read!(tenant: facility.id, authorize?: false)
          |> Enum.take(3)

        Enum.each(audience, fn resident ->
          Feed.PostAudience
          |> Ash.Changeset.for_create(
            :create,
            %{
              facility_id: facility.id,
              post_id: post.id,
              resident_id: resident.id
            },
            tenant: facility.id,
            authorize?: false
          )
          |> Ash.create!(tenant: facility.id, authorize?: false)
        end)

        post
    end
  end

  defp seed_demo_interactions(facility, post) do
    relatives =
      People.Relative
      |> Ash.read!(tenant: facility.id, authorize?: false)
      |> Enum.take(3)

    if length(relatives) >= 3 do
      seed_comments_once(facility, post, relatives)
      seed_reactions_once(facility, post, relatives)
      seed_tags_once(facility, post)
    end
  end

  defp seed_comments_once(facility, post, relatives) do
    existing =
      Feed.Comment
      |> Ash.Query.filter(post_id == ^post.id)
      |> Ash.read!(tenant: facility.id, authorize?: false)

    if existing == [] do
      relatives
      |> Enum.take(length(@demo_comments))
      |> Enum.zip(@demo_comments)
      |> Enum.each(fn {relative, body} ->
        Feed.Comment
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: facility.id,
            post_id: post.id,
            author_user_id: relative.user_id,
            body: body
          },
          tenant: facility.id,
          authorize?: false
        )
        |> Ash.create!(tenant: facility.id, authorize?: false)
      end)
    end
  end

  defp seed_reactions_once(facility, post, relatives) do
    existing =
      Feed.Reaction
      |> Ash.Query.filter(post_id == ^post.id)
      |> Ash.read!(tenant: facility.id, authorize?: false)

    if existing == [] do
      Enum.each(relatives, fn relative ->
        Feed.Reaction
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: facility.id,
            post_id: post.id,
            user_id: relative.user_id,
            kind: :like
          },
          tenant: facility.id,
          authorize?: false
        )
        |> Ash.create!(tenant: facility.id, authorize?: false)
      end)
    end
  end

  defp seed_tags_once(facility, post) do
    existing =
      Feed.ResidentTagOnPost
      |> Ash.Query.filter(post_id == ^post.id)
      |> Ash.read!(tenant: facility.id, authorize?: false)

    if existing == [] do
      residents =
        People.Resident
        |> Ash.read!(tenant: facility.id, authorize?: false)
        |> Enum.take(3)

      Enum.each(residents, fn resident ->
        Feed.ResidentTagOnPost
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: facility.id,
            post_id: post.id,
            resident_id: resident.id
          },
          tenant: facility.id,
          authorize?: false
        )
        |> Ash.create!(tenant: facility.id, authorize?: false)
      end)
    end
  end

  defp find_or_create_residents(facility, primary_ward, secondary_ward) do
    existing =
      People.Resident
      |> Ash.read!(tenant: facility.id, authorize?: false)
      |> length()

    needed = @resident_count - existing

    if needed > 0 do
      for i <- 1..needed do
        ward = if rem(i, 3) == 0, do: secondary_ward, else: primary_ward

        attrs = %{
          facility_id: facility.id,
          ward_id: ward.id,
          first_name: NamePool.random_first_name(),
          last_name: NamePool.random_last_name(),
          date_of_birth: NamePool.random_birth_date()
        }

        People.Resident
        |> Ash.Changeset.for_create(:create, attrs,
          tenant: facility.id,
          authorize?: false
        )
        |> Ash.create!(tenant: facility.id, authorize?: false)
      end
    end
  end

  defp find_or_create_relatives_and_links(facility) do
    residents =
      People.Resident
      |> Ash.read!(tenant: facility.id, authorize?: false)

    existing =
      People.Relative
      |> Ash.read!(tenant: facility.id, authorize?: false)
      |> length()

    needed = @relative_count_target - existing

    if needed > 0 and residents != [] do
      for _ <- 1..needed do
        first = NamePool.random_first_name()
        last = NamePool.random_last_name()
        suffix = :erlang.unique_integer([:positive])

        email =
          "#{String.downcase(first)}.#{String.downcase(last)}.#{suffix}@example.test"

        user =
          Accounts.User
          |> Ash.Changeset.for_create(
            :register_with_password,
            %{
              email: email,
              name: first,
              family_name: last,
              password: @bulk_password,
              password_confirmation: @bulk_password
            },
            authorize?: false
          )
          |> Ash.create!(authorize?: false)

        user
        |> Ash.Changeset.for_update(:update_profile, %{}, authorize?: false)
        |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
        |> Ash.update!(authorize?: false)

        relative =
          People.Relative
          |> Ash.Changeset.for_create(
            :create,
            %{
              facility_id: facility.id,
              user_id: user.id,
              display_name: "#{first} #{last}"
            },
            tenant: facility.id,
            authorize?: false
          )
          |> Ash.create!(tenant: facility.id, authorize?: false)

        Ash.create!(
          Org.FacilityMembership,
          %{
            facility_id: facility.id,
            user_id: user.id,
            role: :relative,
            source: :manual
          },
          authorize?: false
        )

        resident = Enum.random(residents)
        relationship = Enum.random(@relationship_pool)

        People.RelativeOfResident
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: facility.id,
            resident_id: resident.id,
            relative_id: relative.id,
            relationship: relationship
          },
          tenant: facility.id,
          authorize?: false
        )
        |> Ash.create!(tenant: facility.id, authorize?: false)
      end
    end
  end

  defp find_or_create_district do
    find_or_create(
      Org.District |> Ash.Query.filter(slug == "sandbox"),
      Org.District,
      %{name: "Sandbox District", slug: "sandbox"}
    )
  end

  defp find_or_create_facility(district) do
    find_or_create(
      Org.Facility |> Ash.Query.filter(slug == "sandbox-home"),
      Org.Facility,
      %{district_id: district.id, name: "Sandbox Care Home", slug: "sandbox-home"}
    )
  end

  defp find_or_create_primary_ward(facility) do
    find_or_create(
      Org.Ward |> Ash.Query.filter(facility_id == ^facility.id and name == "Ground Floor"),
      Org.Ward,
      %{facility_id: facility.id, name: "Ground Floor"}
    )
  end

  defp find_or_create_secondary_ward(facility) do
    find_or_create(
      Org.Ward |> Ash.Query.filter(facility_id == ^facility.id and name == "First Floor"),
      Org.Ward,
      %{facility_id: facility.id, name: "First Floor"}
    )
  end

  defp find_or_create_team(%{handle: handle, name: name, role_kind: role_kind}, facility) do
    case Ash.read_one(
           Accounts.TeamIdentity |> Ash.Query.filter(handle == ^handle),
           authorize?: false
         ) do
      {:ok, nil} ->
        Accounts.TeamIdentity
        |> Ash.Changeset.for_create(
          :register_with_password,
          %{
            handle: handle,
            name: name,
            role_kind: role_kind,
            facility_id: facility.id,
            password: @demo_password
          },
          authorize?: false
        )
        |> Ash.create!(authorize?: false)

      {:ok, _existing} ->
        :ok
    end
  end

  defp find_or_create_relative do
    case Ash.read_one(
           Accounts.User |> Ash.Query.filter(email == ^@relative_email),
           authorize?: false
         ) do
      {:ok, nil} ->
        user =
          Accounts.User
          |> Ash.Changeset.for_create(
            :register_with_password,
            %{
              email: @relative_email,
              name: "Demo",
              family_name: "Relative",
              password: @demo_password,
              password_confirmation: @demo_password
            },
            authorize?: false
          )
          |> Ash.create!(authorize?: false)

        user
        |> Ash.Changeset.for_update(:update_profile, %{}, authorize?: false)
        |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
        |> Ash.update!(authorize?: false)

      {:ok, existing} ->
        existing
    end
  end

  defp find_or_create_membership(relative, facility) do
    case Ash.read_one(
           Org.FacilityMembership
           |> Ash.Query.filter(user_id == ^relative.id and facility_id == ^facility.id),
           authorize?: false
         ) do
      {:ok, nil} ->
        Ash.create!(
          Org.FacilityMembership,
          %{
            facility_id: facility.id,
            user_id: relative.id,
            role: :relative,
            source: :manual
          },
          authorize?: false
        )

      {:ok, _existing} ->
        :ok
    end
  end

  defp find_or_create(query, resource, attrs) do
    case Ash.read_one(query, authorize?: false) do
      {:ok, nil} -> Ash.create!(resource, attrs, authorize?: false)
      {:ok, existing} -> existing
    end
  end
end
