defmodule Caredeck.Release.Seeds do
  alias Caredeck.Accounts
  alias Caredeck.Feed
  alias Caredeck.Kitchen
  alias Caredeck.Formfix
  alias Caredeck.Org
  alias Caredeck.People
  alias Caredeck.Release.NamePool
  alias Caredeck.Services

  require Ash.Query

  @relative_email "demo-relative@example.test"
  @demo_password "phase1-demo-pass"
  @bulk_password "phase2-bulk-pass"

  @team_seeds [
    %{name: "Team Admin", handle: "team-admin", role_kind: :admin},
    %{name: "Team Care", handle: "team-care", role_kind: :care},
    %{name: "Team Activities", handle: "team-activities", role_kind: :activities},
    %{name: "Team Therapy", handle: "team-therapy", role_kind: :therapy},
    %{name: "Team Kitchen", handle: "team-kitchen", role_kind: :kitchen}
  ]

  @resident_count 30
  @relative_count_target 80
  @relationship_pool ~w(daughter son niece nephew granddaughter grandson spouse sibling)a

  @demo_post_body "Good news! Mr Hungsinger had a very good report from his physiotherapist today."

  @demo_comments [
    "Wonderful to hear, thank you for the update.",
    "Please pass along our love."
  ]

  @placeholder_jpeg Base.decode64!(
                      "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ" <>
                        "EBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQ" <>
                        "EBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ" <>
                        "EBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAA" <>
                        "AAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFAEBAAAAAAAAAAAAAAAAAAAAAP/EAB" <>
                        "QRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/AL+AB//Z"
                    )

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
    seed_kitchen(facility)
    seed_services(facility)
    seed_formfix(facility)
    seed_formfix_demo_notes(facility)

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

    IO.puts(
      "  Teams:    team-care · team-activities · team-therapy · team-kitchen / #{@demo_password}"
    )

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

  @service_provider_seeds [
    %{
      kind: :pharmacy,
      name: "Demo Pharmacy",
      handle: "team-pharmacy",
      window: "Mon–Fri 09:00–18:00",
      target_hours: 24
    },
    %{
      kind: :laundry,
      name: "Linen Service",
      handle: "team-laundry",
      window: "Mon, Wed, Fri",
      target_hours: 48
    },
    %{
      kind: :hairdresser,
      name: "Salon Demo",
      handle: "team-hairdresser",
      window: "Tue & Thu afternoons",
      target_hours: 72
    },
    %{
      kind: :doctor,
      name: "Family Doctor Demo",
      handle: "team-doctor",
      window: "Mon–Fri 08:00–16:00",
      target_hours: 24
    }
  ]

  defp seed_services(facility) do
    Enum.each(@service_provider_seeds, fn p ->
      team = find_or_create_service_team(p, facility)
      find_or_create_service_provider(p, team, facility)
    end)

    :ok
  end

  defp find_or_create_service_team(%{handle: handle, name: name}, facility) do
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
            role_kind: :service,
            facility_id: facility.id,
            password: @demo_password
          },
          authorize?: false
        )
        |> Ash.create!(authorize?: false)

      {:ok, existing} ->
        existing
    end
  end

  defp find_or_create_service_provider(p, team, facility) do
    case Ash.read_one(
           Services.ServiceProvider |> Ash.Query.filter(kind == ^p.kind),
           tenant: facility.id,
           authorize?: false
         ) do
      {:ok, nil} ->
        Services.ServiceProvider
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: facility.id,
            kind: p.kind,
            name: p.name,
            display_name: p.name,
            response_window_label: p.window,
            response_time_target_hours: p.target_hours,
            team_identity_id: team.id
          },
          tenant: facility.id,
          authorize?: false
        )
        |> Ash.create!(tenant: facility.id, authorize?: false)

      {:ok, existing} ->
        existing
    end
  end

  defp seed_formfix(facility) do
    with %{} = user <- find_demo_relative_user(),
         %{} = resident <- first_linked_resident(user, facility) do
      existing =
        Formfix.Application
        |> Ash.Query.filter(applicant_user_id == ^user.id and resident_id == ^resident.id)
        |> Ash.read!(tenant: facility.id, authorize?: false)

      if existing == [] do
        app = Formfix.Applications.start_for_resident!(facility, resident, user)
        prefill_person_needing_care!(app, resident, facility)
        prefill_applicant!(app, user, facility)
      end

      backfill_verified_documents!(facility)
    else
      _ -> :ok
    end
  end

  defp seed_formfix_demo_notes(facility) do
    admin =
      Accounts.TeamIdentity
      |> Ash.Query.filter(handle == "team-admin" and facility_id == ^facility.id)
      |> Ash.read_one!(authorize?: false)

    case admin do
      nil ->
        :ok

      _ ->
        Formfix.Application
        |> Ash.Query.filter(state in [:draft, :missing_documents, :ready_to_submit, :submitted, :approved])
        |> Ash.read!(tenant: facility.id, authorize?: false)
        |> Enum.each(&ensure_demo_notes!(&1, admin, facility))
    end
  end

  defp ensure_demo_notes!(app, admin, facility) do
    existing =
      Formfix.ApplicationNote
      |> Ash.Query.filter(application_id == ^app.id)
      |> Ash.read!(tenant: facility.id, authorize?: false)

    if existing == [] do
      Enum.each(
        [
          "Reviewed initial submission, all sections look complete.",
          "Documents verified by counsel."
        ],
        fn body ->
          Formfix.ApplicationNote
          |> Ash.Changeset.for_create(
            :create,
            %{
              facility_id: facility.id,
              application_id: app.id,
              author_team_id: admin.id,
              body: body
            },
            tenant: facility.id,
            authorize?: false
          )
          |> Ash.create!(tenant: facility.id, authorize?: false)
        end
      )
    end
  end

  defp backfill_verified_documents!(facility) do
    Formfix.Application
    |> Ash.Query.filter(state in [:draft, :missing_documents, :ready_to_submit])
    |> Ash.read!(tenant: facility.id, authorize?: false)
    |> Enum.each(fn app ->
      sections =
        Formfix.ApplicationSection
        |> Ash.Query.filter(application_id == ^app.id)
        |> Ash.read!(tenant: facility.id, authorize?: false)

      if sections != [] and
           Enum.all?(sections, &(&1.status in [:complete, :skipped])) do
        ensure_verified_documents!(app, sections, facility)
        :ok = Formfix.Applications.recompute_status(app)
      end
    end)
  end

  defp ensure_verified_documents!(app, sections, facility) do
    for section <- sections, section.status == :complete do
      for slot <- Formfix.RequiredDocuments.for(section.section_key) do
        existing =
          Formfix.UploadedDocument
          |> Ash.Query.filter(
            application_id == ^app.id and section_key == ^section.section_key and
              document_key == ^slot.key
          )
          |> Ash.read!(tenant: facility.id, authorize?: false)

        if Enum.any?(existing, &(&1.state == :verified)) do
          :ok
        else
          create_verified_demo_document!(app, section.section_key, slot.key, facility)
        end
      end
    end
  end

  defp create_verified_demo_document!(app, section_key, document_key, facility) do
    doc =
      Formfix.UploadedDocument
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          application_id: app.id,
          section_key: section_key,
          document_key: document_key,
          s3_key: "seed/demo-#{section_key}-#{document_key}.pdf",
          original_filename: "demo-#{document_key}.pdf",
          bytes: 1024,
          mime_type: "application/pdf"
        },
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)

    doc
    |> Ash.Changeset.for_update(:start_verification, %{}, tenant: facility.id, authorize?: false)
    |> Ash.update!(tenant: facility.id, authorize?: false)
    |> Ash.Changeset.for_update(:mark_verified, %{}, tenant: facility.id, authorize?: false)
    |> Ash.update!(tenant: facility.id, authorize?: false)
  end

  defp find_demo_relative_user do
    Accounts.User
    |> Ash.Query.filter(email == ^@relative_email)
    |> Ash.read_one!(authorize?: false)
  end

  defp first_linked_resident(user, facility) do
    relative_ids =
      People.Relative
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.read!(tenant: facility.id, authorize?: false)
      |> Enum.map(& &1.id)

    case relative_ids do
      [] ->
        nil

      ids ->
        resident_ids =
          People.RelativeOfResident
          |> Ash.Query.filter(relative_id in ^ids)
          |> Ash.Query.sort(inserted_at: :asc)
          |> Ash.read!(tenant: facility.id, authorize?: false)
          |> Enum.map(& &1.resident_id)
          |> Enum.uniq()

        case resident_ids do
          [] ->
            nil

          [rid | _] ->
            People.Resident
            |> Ash.get!(rid, tenant: facility.id, authorize?: false)
        end
    end
  end

  defp prefill_person_needing_care!(application, resident, facility) do
    Formfix.SectionWriter.save_answers!(application, :person_needing_care, %{
      "first_name" => resident.first_name,
      "last_name" => resident.last_name,
      "date_of_birth" =>
        if(resident.date_of_birth, do: Date.to_iso8601(resident.date_of_birth), else: ""),
      "marital_status" => "widowed",
      "postal_code" => "12345",
      "street" => "1 Demo Lane",
      "city" => "Demo City"
    })

    _ = facility
    :ok
  end

  defp prefill_applicant!(application, user, facility) do
    Formfix.SectionWriter.save_answers!(application, :applicant, %{
      "first_name" => user.name || "Demo",
      "last_name" => user.family_name || "Relative"
    })

    _ = facility
    :ok
  end

  @kitchen_products [
    {:breakfast, ["Granola bowl", "Porridge", "Scrambled eggs"]},
    {:lunch, ["Roast chicken", "Vegetable curry", "Pasta primavera"]},
    {:dinner, ["Soup of the day", "Fish & potatoes", "Chickpea stew"]},
    {:drinks, ["Apple juice", "Herbal tea", "Mineral water"]},
    {:fruit, ["Apple", "Banana", "Seasonal mix"]},
    {:snack, ["Yogurt", "Pretzel", "Trail mix"]}
  ]

  defp seed_kitchen(facility) do
    existing_count =
      Kitchen.Product
      |> Ash.read!(tenant: facility.id, authorize?: false)
      |> length()

    if existing_count == 0 do
      products =
        Enum.flat_map(@kitchen_products, fn {cat, names} ->
          Enum.map(names, fn name ->
            Kitchen.Product
            |> Ash.Changeset.for_create(
              :create,
              %{
                facility_id: facility.id,
                name: name,
                category: cat,
                is_default: true
              },
              tenant: facility.id,
              authorize?: false
            )
            |> Ash.create!(tenant: facility.id, authorize?: false)
          end)
        end)

      template =
        Kitchen.MenuTemplate
        |> Ash.Changeset.for_create(
          :create,
          %{facility_id: facility.id, name: "Default week", is_active: true},
          tenant: facility.id,
          authorize?: false
        )
        |> Ash.create!(tenant: facility.id, authorize?: false)

      product_by_category = Enum.group_by(products, & &1.category)

      for day <- ~w(monday tuesday wednesday thursday friday saturday sunday)a,
          cat <- Kitchen.MealCategory.all() do
        product = product_by_category |> Map.fetch!(cat) |> hd()

        Kitchen.MenuTemplateSlot
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: facility.id,
            menu_template_id: template.id,
            day_of_week: day,
            category: cat,
            product_id: product.id
          },
          tenant: facility.id,
          authorize?: false
        )
        |> Ash.create!(tenant: facility.id, authorize?: false)
      end
    end

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
