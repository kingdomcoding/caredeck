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
    %{name: "Maria Hoffmann", handle: "team-admin", role_kind: :admin},
    %{name: "Greta Becker", handle: "team-care", role_kind: :care},
    %{name: "Anika Vogel", handle: "team-activities", role_kind: :activities},
    %{name: "Lars Hartmann", handle: "team-therapy", role_kind: :therapy},
    %{name: "Stefan Weber", handle: "team-kitchen", role_kind: :kitchen}
  ]

  @kitchen_products [
    {:breakfast,
     [
       "Porridge with berries",
       "Granola bowl",
       "Brötchen with cold cuts",
       "Bircher muesli",
       "Scrambled eggs",
       "Pancakes with apple sauce",
       "Frühstücksei with toast"
     ]},
    {:lunch,
     [
       "Wiener Schnitzel",
       "Beef Goulash with Spätzle",
       "Pan-fried fish with potatoes",
       "Rouladen with red cabbage",
       "Lentil stew",
       "Käsespätzle",
       "Königsberger Klopse"
     ]},
    {:dinner,
     [
       "Vegetable soup",
       "Bauernbrot with cheese",
       "Quark with chives",
       "Leberwurst sandwich",
       "Kartoffelsalat",
       "Bratwurst with sauerkraut",
       "Maultaschen in broth"
     ]},
    {:drinks,
     [
       "Apple juice",
       "Herbal tea",
       "Mineral water",
       "Coffee",
       "Berry compote",
       "Buttermilk",
       "Black tea"
     ]},
    {:fruit, ["Apple", "Pear", "Banana", "Plum", "Seasonal berries", "Orange", "Grapes"]},
    {:snack,
     [
       "Yogurt",
       "Pretzel",
       "Trail mix",
       "Quark dessert",
       "Cheese cubes",
       "Cookies",
       "Apfelstrudel"
     ]}
  ]

  @kitchen_days_order ~w(monday tuesday wednesday thursday friday saturday sunday)a

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

  def refresh! do
    Application.put_env(:caredeck, :thumbnailer_mode, :sync)

    district = find_or_create_district()
    facility = find_or_create_facility(district)
    Enum.each(@team_seeds, &find_or_create_team(&1, facility))

    admin =
      Accounts.TeamIdentity
      |> Ash.Query.filter(handle == "team-admin" and facility_id == ^facility.id)
      |> Ash.read_one!(authorize?: false)

    Formfix.Application
    |> Ash.read!(tenant: facility.id, authorize?: false)
    |> Ash.load!(:resident, tenant: facility.id, authorize?: false)
    |> Enum.each(&refresh_application!(&1, admin, facility))

    refresh_kitchen_slots!(facility)
    rematerialise_kitchen_days!(facility)

    refresh_avatars!(facility)
    refresh_feed!(facility)
    refresh_services!(facility)
    refresh_caregivers!(facility)
    refresh_kitchen_orders_and_diets!(facility)
    refresh_formfix_apps!(facility)
    refresh_notifications!(facility)
    refresh_pending_invitations!(facility)

    IO.puts("")
    IO.puts("Demo data refreshed.")
    IO.puts("")

    :ok
  end

  @pending_invitation_seeds [
    %{resident: {"Edward", "Brooks"}, email: "thomas.brooks@example.test", relationship: :son},
    %{
      resident: {"Audrey", "Edwards"},
      email: "lisa.edwards@example.test",
      relationship: :daughter
    },
    %{resident: {"Doris", "Hall"}, email: "robert.hall@example.test", relationship: :nephew}
  ]

  defp refresh_pending_invitations!(facility) do
    IO.puts("  ↺ seeding pending invitations")
    fid = Ecto.UUID.dump!(facility.id)

    {:ok, _} =
      Caredeck.Repo.query(
        "DELETE FROM relative_invitations_versions WHERE facility_id = $1 AND id IN (SELECT id FROM relative_invitations WHERE accepted_at IS NULL AND email LIKE '%@example.test' AND facility_id = $1)",
        [fid]
      )

    {:ok, _} =
      Caredeck.Repo.query(
        "DELETE FROM relative_invitations WHERE accepted_at IS NULL AND email LIKE '%@example.test' AND facility_id = $1",
        [fid]
      )

    residents =
      People.Resident
      |> Ash.read!(tenant: facility.id, authorize?: false)

    demo_user = find_demo_relative_user()

    seeded =
      Enum.reduce(@pending_invitation_seeds, [], fn spec, acc ->
        case find_resident(residents, spec.resident) do
          nil ->
            acc

          resident ->
            try do
              {:ok, _inv} =
                People.RelativeInvitation
                |> Ash.Changeset.for_create(
                  :create,
                  %{
                    facility_id: facility.id,
                    inviter_user_id: demo_user.id,
                    resident_id: resident.id,
                    email: spec.email,
                    suggested_relationship: spec.relationship
                  },
                  tenant: facility.id,
                  authorize?: false
                )
                |> Ash.create(tenant: facility.id, authorize?: false)

              [spec.email | acc]
            rescue
              _ -> acc
            end
        end
      end)

    IO.puts("  ✓ pending invitations: #{length(seeded)}")
    :ok
  end

  @extra_formfix_seeds [
    %{resident: {"Constance", "King"}, target_state: :draft, target_progress: 12},
    %{resident: {"Penelope", "Davis"}, target_state: :draft, target_progress: 67},
    %{resident: {"Edward", "Brooks"}, target_state: :draft, target_progress: 85},
    %{resident: {"Mabel", "Martin"}, target_state: :missing_documents, target_progress: 100},
    %{resident: {"Beatrice", "Cox"}, target_state: :ready_to_submit, target_progress: 100},
    %{
      resident: {"Julian", "Adams"},
      target_state: :submitted,
      target_progress: 100,
      submitted_days_ago: 3
    },
    %{
      resident: {"Doris", "Hall"},
      target_state: :approved,
      target_progress: 100,
      submitted_days_ago: 14,
      decided_days_ago: 4,
      outcome: "Pflegegrad 4 approved by MDK. Welfare-law allowance granted from 1 May."
    }
  ]

  defp refresh_formfix_apps!(facility) do
    IO.puts("  ↺ seeding extra Formfix applications")

    residents =
      People.Resident
      |> Ash.read!(tenant: facility.id, authorize?: false)

    demo_user = find_demo_relative_user()

    Enum.each(@extra_formfix_seeds, fn spec ->
      case find_resident(residents, spec.resident) do
        nil ->
          :ok

        resident ->
          existing =
            Formfix.Application
            |> Ash.Query.filter(resident_id == ^resident.id)
            |> Ash.read_one(tenant: facility.id, authorize?: false)

          case existing do
            {:ok, %{} = _} ->
              :ok

            _ ->
              create_formfix_app!(spec, resident, facility, demo_user)
          end
      end
    end)

    IO.puts("  ✓ formfix: +#{length(@extra_formfix_seeds)} applications")
    :ok
  end

  defp create_formfix_app!(spec, resident, facility, demo_user) do
    app = Formfix.Applications.start_for_resident!(facility, resident, demo_user)

    sections =
      Formfix.ApplicationSection
      |> Ash.Query.filter(application_id == ^app.id)
      |> Ash.Query.sort(position: :asc)
      |> Ash.read!(tenant: facility.id, authorize?: false)

    fill_count =
      case spec.target_progress do
        12 -> 2
        67 -> 9
        85 -> 12
        100 -> length(sections)
        _ -> 4
      end

    sections_to_fill = Enum.take(sections, fill_count)

    Enum.each(sections_to_fill, fn section ->
      fill_section!(app, resident, section.section_key, facility)
    end)

    fid = Ecto.UUID.dump!(facility.id)
    aid = Ecto.UUID.dump!(app.id)

    case spec.target_state do
      :draft ->
        :ok

      :missing_documents ->
        Caredeck.Repo.query(
          "UPDATE formfix_applications SET state = 'missing_documents' WHERE id = $1",
          [aid]
        )

      :ready_to_submit ->
        backfill_all_docs!(app, facility)

        Caredeck.Repo.query(
          "UPDATE formfix_applications SET state = 'ready_to_submit' WHERE id = $1",
          [aid]
        )

      :submitted ->
        backfill_all_docs!(app, facility)
        ts = days_ago_dt(spec.submitted_days_ago)

        Caredeck.Repo.query(
          "UPDATE formfix_applications SET state = 'submitted', submitted_at = $1 WHERE id = $2",
          [ts, aid]
        )

      :approved ->
        backfill_all_docs!(app, facility)
        s_ts = days_ago_dt(spec.submitted_days_ago)
        d_ts = days_ago_dt(spec.decided_days_ago)

        Caredeck.Repo.query(
          """
          UPDATE formfix_applications
          SET state = 'approved', submitted_at = $1, decided_at = $2, outcome = $3
          WHERE id = $4
          """,
          [s_ts, d_ts, spec.outcome, aid]
        )
    end

    _ = fid
    :ok
  end

  defp fill_section!(_app, _resident, :welcome, _facility), do: :ok

  defp fill_section!(app, resident, :person_needing_care, facility) do
    prefill_person_needing_care!(app, resident, facility)
  end

  defp fill_section!(app, _resident, :applicant, facility) do
    Formfix.SectionWriter.save_answers!(app, :applicant, %{
      "first_name" => "Demo",
      "last_name" => "Relative",
      "relationship" => "Daughter",
      "phone" => "+49 30 1234567",
      "email" => @relative_email
    })

    _ = facility
    :ok
  end

  defp fill_section!(app, _resident, :care_situation, facility) do
    Formfix.SectionWriter.save_answers!(app, :care_situation, %{
      "care_level_assigned_since" => "2024-06-01",
      "current_care_setting" => "home",
      "care_level" => "3"
    })

    _ = facility
    :ok
  end

  defp fill_section!(app, _resident, :income, facility) do
    Formfix.SectionWriter.save_answers!(app, :income, %{
      "pension_monthly" => "1842",
      "rental_income_monthly" => "0"
    })

    _ = facility
    :ok
  end

  defp fill_section!(app, _resident, :assets, facility) do
    Formfix.SectionWriter.save_answers!(app, :assets, %{
      "savings_total" => "8420"
    })

    _ = facility
    :ok
  end

  defp fill_section!(app, _resident, :gifts_given, facility) do
    Formfix.SectionWriter.save_answers!(app, :gifts_given, %{
      "any_gifts_over_500" => "false"
    })

    _ = facility
    :ok
  end

  defp fill_section!(app, _resident, :expenses, facility) do
    Formfix.SectionWriter.save_answers!(app, :expenses, %{
      "rent_monthly" => "780"
    })

    _ = facility
    :ok
  end

  defp fill_section!(app, _resident, :disability, facility) do
    Formfix.SectionWriter.save_answers!(app, :disability, %{
      "recognised_disability_status" => "false"
    })

    _ = facility
    :ok
  end

  defp fill_section!(app, _resident, :foreign_nationality, facility) do
    Formfix.SectionWriter.save_answers!(app, :foreign_nationality, %{
      "nationality" => "Deutsch"
    })

    _ = facility
    :ok
  end

  defp fill_section!(_app, _resident, _other, _facility), do: :ok

  defp backfill_all_docs!(app, facility) do
    sections =
      Formfix.ApplicationSection
      |> Ash.Query.filter(application_id == ^app.id)
      |> Ash.read!(tenant: facility.id, authorize?: false)

    ensure_verified_documents!(app, sections, facility)
  end

  defp days_ago_dt(days) do
    DateTime.utc_now() |> DateTime.add(-days * 86_400, :second) |> DateTime.to_naive()
  end

  defp refresh_notifications!(facility) do
    IO.puts("  ↺ refreshing notifications via fanout worker")
    fid = Ecto.UUID.dump!(facility.id)

    Enum.each(
      ~w(notifications_versions notifications),
      fn tbl ->
        {:ok, _} =
          Caredeck.Repo.query("DELETE FROM " <> tbl <> " WHERE facility_id = $1", [fid])
      end
    )

    posts =
      Feed.Post
      |> Ash.read!(tenant: facility.id, authorize?: false)

    Enum.each(posts, fn post ->
      Caredeck.Workers.NotificationFanout.perform(%Oban.Job{
        args: %{
          "event" => "post_created",
          "post_id" => post.id,
          "facility_id" => facility.id
        }
      })
    end)

    comments =
      Feed.Comment
      |> Ash.read!(tenant: facility.id, authorize?: false)

    Enum.each(comments, fn comment ->
      Caredeck.Workers.NotificationFanout.perform(%Oban.Job{
        args: %{
          "event" => "comment_created",
          "comment_id" => comment.id,
          "facility_id" => facility.id
        }
      })
    end)

    reactions =
      Feed.Reaction
      |> Ash.read!(tenant: facility.id, authorize?: false)

    Enum.each(reactions, fn reaction ->
      Caredeck.Workers.NotificationFanout.perform(%Oban.Job{
        args: %{
          "event" => "reaction_created",
          "reaction_id" => reaction.id,
          "facility_id" => facility.id
        }
      })
    end)

    IO.puts(
      "  ✓ notifications fanned out for #{length(posts)} posts, #{length(comments)} comments, #{length(reactions)} reactions"
    )

    :ok
  end

  @diet_profile_seeds [
    %{
      resident: {"Irene", "Cook"},
      allergens: ["shellfish"],
      preferences: ["no spicy food"],
      skip_categories: [:snack],
      notes: "Family asked we keep snacks minimal in the afternoon."
    },
    %{
      resident: {"Julian", "Adams"},
      allergens: [],
      preferences: ["vegetarian for religious reasons"],
      skip_categories: [:dinner],
      notes: "Late dinner skipped — light evening tea only."
    },
    %{
      resident: {"Isaac", "Allen"},
      allergens: ["gluten", "lactose"],
      preferences: ["soft food only after dental work"],
      skip_categories: [],
      notes: "Family noted: no sugary snacks per cardiologist."
    },
    %{
      resident: {"Beatrice", "Cox"},
      allergens: ["tree nuts"],
      preferences: ["decaf coffee only after 14:00"],
      skip_categories: [],
      notes: ""
    },
    %{
      resident: {"Penelope", "Davis"},
      allergens: [],
      preferences: ["low-sodium per cardiologist"],
      skip_categories: [],
      notes: "Sodium restriction is strict — no added salt please."
    },
    %{
      resident: {"Edward", "Brooks"},
      allergens: ["strawberries"],
      preferences: ["small portions"],
      skip_categories: [:fruit],
      notes: ""
    }
  ]

  defp refresh_kitchen_orders_and_diets!(facility) do
    IO.puts("  ↺ seeding kitchen orders + diet profiles")
    fid = Ecto.UUID.dump!(facility.id)

    Enum.each(
      ~w(kitchen_resident_meal_orders_versions kitchen_resident_meal_orders
         kitchen_resident_diet_profiles_versions kitchen_resident_diet_profiles),
      fn tbl ->
        {:ok, _} =
          Caredeck.Repo.query("DELETE FROM " <> tbl <> " WHERE facility_id = $1", [fid])
      end
    )

    residents =
      People.Resident
      |> Ash.read!(tenant: facility.id, authorize?: false)

    # Seed diet profiles
    Enum.each(@diet_profile_seeds, fn spec ->
      case find_resident(residents, spec.resident) do
        nil ->
          :ok

        r ->
          Kitchen.ResidentDietProfile
          |> Ash.Changeset.for_create(
            :create,
            %{
              facility_id: facility.id,
              resident_id: r.id,
              allergens: spec.allergens,
              preferences: spec.preferences,
              skip_categories: spec.skip_categories,
              notes: spec.notes
            },
            tenant: facility.id,
            authorize?: false
          )
          |> Ash.create!(tenant: facility.id, authorize?: false)
      end
    end)

    care_team =
      Accounts.TeamIdentity
      |> Ash.Query.filter(handle == "team-care" and facility_id == ^facility.id)
      |> Ash.read_one!(authorize?: false)

    today = Date.utc_today()

    # Pick first 8 residents for today's orders, distributed across categories
    sample_residents = Enum.take(residents, 8)

    # Build product lookup by category
    products =
      Kitchen.Product
      |> Ash.read!(tenant: facility.id, authorize?: false)

    product_by_cat = Enum.group_by(products, & &1.category)

    # Today: 15 orders mixed states
    seed_orders_for_date!(facility, sample_residents, product_by_cat, care_team, today, %{
      breakfast: 4,
      lunch: 5,
      dinner: 3,
      snack: 3
    })

    # Tomorrow: 8 orders
    seed_orders_for_date!(
      facility,
      sample_residents,
      product_by_cat,
      care_team,
      Date.add(today, 1),
      %{
        breakfast: 3,
        lunch: 3,
        dinner: 2
      }
    )

    # Day after: 6 orders
    seed_orders_for_date!(
      facility,
      sample_residents,
      product_by_cat,
      care_team,
      Date.add(today, 2),
      %{
        breakfast: 2,
        lunch: 2,
        dinner: 2
      }
    )

    IO.puts("  ✓ diet profiles: #{length(@diet_profile_seeds)}; orders seeded for today + 2 days")
    :ok
  end

  defp seed_orders_for_date!(facility, residents, product_by_cat, care_team, date, counts) do
    Enum.each(counts, fn {category, count} ->
      products = Map.get(product_by_cat, category, [])

      if products != [] do
        residents
        |> Enum.take(count)
        |> Enum.with_index()
        |> Enum.each(fn {resident, idx} ->
          product = Enum.at(products, rem(idx, length(products)))

          state =
            cond do
              date != Date.utc_today() -> :ordered
              idx < div(count, 3) -> :served
              idx == count - 1 -> :cancelled
              true -> :ordered
            end

          Kitchen.ResidentMealOrder
          |> Ash.Changeset.for_create(
            :create,
            %{
              facility_id: facility.id,
              resident_id: resident.id,
              date: date,
              category: category,
              product_id: product.id,
              state: state,
              ordered_by_team_id: care_team.id
            },
            tenant: facility.id,
            authorize?: false
          )
          |> Ash.create!(tenant: facility.id, authorize?: false)
        end)
      end
    end)
  end

  @caregiver_seeds [
    %{
      display_name: "Maria Hoffmann",
      role_label: "Pflegedienstleitung",
      email: "maria.hoffmann@spring-hill.demo"
    },
    %{
      display_name: "Tomas Lange",
      role_label: "Pflegefachkraft",
      email: "tomas.lange@spring-hill.demo"
    },
    %{
      display_name: "Heike Krüger",
      role_label: "Pflegehelferin",
      email: "heike.krueger@spring-hill.demo"
    },
    %{
      display_name: "Jonas Werner",
      role_label: "Ergotherapeut",
      email: "jonas.werner@spring-hill.demo"
    },
    %{
      display_name: "Eva Bauer",
      role_label: "Hauswirtschaft",
      email: "eva.bauer@spring-hill.demo"
    },
    %{
      display_name: "Klaus Richter",
      role_label: "Sozialdienst",
      email: "klaus.richter@spring-hill.demo"
    }
  ]

  defp refresh_caregivers!(facility) do
    IO.puts("  ↺ seeding caregivers")
    fid = Ecto.UUID.dump!(facility.id)

    Enum.each(
      ~w(caregiver_profiles_versions caregiver_profiles),
      fn tbl ->
        {:ok, _} =
          Caredeck.Repo.query("DELETE FROM " <> tbl <> " WHERE facility_id = $1", [fid])
      end
    )

    Enum.with_index(@caregiver_seeds)
    |> Enum.each(fn {spec, idx} ->
      user = find_or_create_caregiver_user!(spec)

      avatar_key =
        Caredeck.Release.Assets.upload!(Caredeck.Release.Assets.at(:avatars_caregiver, idx))

      People.CaregiverProfile
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          user_id: user.id,
          display_name: spec.display_name,
          role_label: spec.role_label,
          avatar_url: avatar_key
        },
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)
    end)

    IO.puts("  ✓ caregivers: #{length(@caregiver_seeds)}")
    :ok
  end

  defp find_or_create_caregiver_user!(%{email: email, display_name: name}) do
    case Accounts.User
         |> Ash.Query.filter(email == ^email)
         |> Ash.read_one(authorize?: false) do
      {:ok, %{} = u} ->
        u

      _ ->
        [first, last] =
          case String.split(name, " ", parts: 2) do
            [f, l] -> [f, l]
            [only] -> [only, "Caregiver"]
          end

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
    end
  end

  @service_request_seeds [
    # Demo Pharmacy
    %{
      provider_kind: :pharmacy,
      subkind: "medication_inquiry",
      state: :open,
      payload: %{
        "subkind" => "medication_inquiry",
        "medication_name" => "Levothyroxin 25µg",
        "question" => "Refill needed by Friday — please confirm pickup time."
      },
      summary: "Levothyroxin refill — pickup Friday",
      resident: {"Constance", "King"},
      requester: :relative,
      days_ago: 0,
      messages: []
    },
    %{
      provider_kind: :pharmacy,
      subkind: "general_question",
      state: :in_progress,
      payload: %{
        "subkind" => "general_question",
        "question" => "Vitamin D house order — can we set up a quarterly subscription?"
      },
      summary: "Vitamin D quarterly order setup",
      resident: nil,
      requester: :care,
      days_ago: 1,
      messages: [
        %{
          author: :provider,
          body: "Sure — we can do every 3 months. Need a signed form. Sending over."
        },
        %{author: :care, body: "Bitte schicken — wir füllen ihn morgen aus."}
      ]
    },
    %{
      provider_kind: :pharmacy,
      subkind: "medication_inquiry",
      state: :resolved,
      payload: %{
        "subkind" => "medication_inquiry",
        "medication_name" => "Ibuprofen 400",
        "question" => "Refill for Mrs Cook — picked up yesterday, all good."
      },
      summary: "Mrs Cook Ibuprofen refill (resolved)",
      resident: {"Irene", "Cook"},
      requester: :care,
      days_ago: 4,
      messages: [
        %{author: :provider, body: "Ready for pickup tomorrow morning."},
        %{author: :care, body: "Danke! Stefan picks up tomorrow."},
        %{author: :provider, body: "Confirmed received."}
      ]
    },
    # Family Doctor Demo
    %{
      provider_kind: :doctor,
      subkind: "appointment_request",
      state: :in_progress,
      payload: %{
        "subkind" => "appointment_request",
        "details" => "Mr Hungsinger — follow-up on physio progress (ROM back to baseline).",
        "preferred_date" => "next Monday"
      },
      summary: "Hungsinger physio follow-up",
      resident: {"Isaac", "Allen"},
      requester: :care,
      days_ago: 2,
      messages: [
        %{author: :provider, body: "Monday 10:30 works. I'll come to ward 1."},
        %{author: :care, body: "Bestens, danke. Wir bereiten alles vor."}
      ]
    },
    %{
      provider_kind: :doctor,
      subkind: "information_request",
      state: :open,
      payload: %{
        "subkind" => "information_request",
        "details" => "Mrs Walker flu shot — has she had it this season? Reviewing records."
      },
      summary: "Mrs Walker flu shot history",
      resident: {"Mabel", "Martin"},
      requester: :care,
      days_ago: 0,
      messages: []
    },
    %{
      provider_kind: :doctor,
      subkind: "information_request",
      state: :resolved,
      payload: %{
        "subkind" => "information_request",
        "details" => "MDK paperwork for Mrs Cook Pflegegrad 4 — forms attached."
      },
      summary: "Mrs Cook Pflegegrad 4 MDK forms",
      resident: {"Irene", "Cook"},
      requester: :care,
      days_ago: 5,
      messages: [
        %{author: :provider, body: "Forms received and signed. Returning by courier today."},
        %{author: :care, body: "Excellent — danke vielmals."}
      ]
    },
    # Salon Demo
    %{
      provider_kind: :hairdresser,
      subkind: "appointment_request",
      state: :open,
      payload: %{
        "subkind" => "appointment_request",
        "haircut_type" => "Short back and sides",
        "notes" => "Mr Adams asked for Thursday afternoon if possible.",
        "post_to_feed" => "false"
      },
      summary: "Mr Adams haircut Thursday",
      resident: {"Julian", "Adams"},
      requester: :relative,
      days_ago: 0,
      messages: []
    },
    %{
      provider_kind: :hairdresser,
      subkind: "appointment_request",
      state: :in_progress,
      payload: %{
        "subkind" => "appointment_request",
        "haircut_type" => "Group cuts (3 residents)",
        "notes" => "Ursula Hall, Penelope Davis, Beatrice Cox — Friday block.",
        "post_to_feed" => "true"
      },
      summary: "Friday group cuts (3 residents)",
      resident: nil,
      requester: :care,
      days_ago: 1,
      messages: [
        %{author: :provider, body: "Friday 14:00–16:30 confirmed."},
        %{author: :care, body: "Perfekt. Bell ward 1 when arriving."}
      ]
    },
    %{
      provider_kind: :hairdresser,
      subkind: "appointment_request",
      state: :resolved,
      payload: %{
        "subkind" => "appointment_request",
        "haircut_type" => "Trim",
        "notes" => "Monthly schedule confirmation — done.",
        "post_to_feed" => "false"
      },
      summary: "Monthly schedule confirmation",
      resident: nil,
      requester: :care,
      days_ago: 6,
      messages: [
        %{author: :provider, body: "All set — same Thursday slot every month."},
        %{author: :care, body: "Großartig, danke!"}
      ]
    },
    # Linen Service (laundry → uses "complaint" subkind but with payload tweak)
    %{
      provider_kind: :laundry,
      subkind: "complaint",
      state: :in_progress,
      payload: %{
        "subkind" => "complaint",
        "service" => "bed_linens",
        "reason" => "schedule",
        "details" => "Bed linens for ward 1 — biweekly rotation; could we shift to weekly?",
        "attachment_id" => "00000000-0000-0000-0000-000000000000"
      },
      summary: "Ward 1 linens — weekly rotation request",
      resident: nil,
      requester: :care,
      days_ago: 3,
      messages: [
        %{author: :provider, body: "Weekly works. Tuesdays + Fridays okay?"},
        %{author: :care, body: "Tue + Fri ist top. Danke!"}
      ]
    },
    %{
      provider_kind: :laundry,
      subkind: "complaint",
      state: :open,
      payload: %{
        "subkind" => "complaint",
        "service" => "towels",
        "reason" => "quality",
        "details" => "Stained towels noted in room 4B — please replace.",
        "attachment_id" => "00000000-0000-0000-0000-000000000000"
      },
      summary: "Stained towels room 4B",
      resident: nil,
      requester: :care,
      days_ago: 0,
      messages: []
    },
    %{
      provider_kind: :laundry,
      subkind: "complaint",
      state: :resolved,
      payload: %{
        "subkind" => "complaint",
        "service" => "blankets",
        "reason" => "quantity",
        "details" => "Extra blankets needed before weekend cold snap — delivered Sat.",
        "attachment_id" => "00000000-0000-0000-0000-000000000000"
      },
      summary: "Extra weekend blankets (resolved)",
      resident: nil,
      requester: :care,
      days_ago: 7,
      messages: [
        %{author: :provider, body: "Delivering 20 extra blankets Saturday morning."},
        %{author: :care, body: "Vielen Dank — perfect timing."},
        %{author: :provider, body: "Delivered. Have a warm weekend!"}
      ]
    }
  ]

  defp refresh_services!(facility) do
    IO.puts("  ↺ rebuilding service requests + messages")

    fid = Ecto.UUID.dump!(facility.id)

    Enum.each(
      ~w(service_messages_versions service_messages service_requests_versions service_requests),
      fn tbl ->
        {:ok, _} =
          Caredeck.Repo.query("DELETE FROM " <> tbl <> " WHERE facility_id = $1", [fid])
      end
    )

    providers =
      Services.ServiceProvider
      |> Ash.read!(tenant: facility.id, authorize?: false)
      |> Map.new(&{&1.kind, &1})

    residents =
      People.Resident
      |> Ash.read!(tenant: facility.id, authorize?: false)

    relative_users = relative_users_with_facility_membership(facility)

    care_team =
      Accounts.TeamIdentity
      |> Ash.Query.filter(handle == "team-care" and facility_id == ^facility.id)
      |> Ash.read_one!(authorize?: false)

    provider_teams =
      Accounts.TeamIdentity
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.role_kind == :service))
      |> Map.new(fn t -> {t.handle, t} end)

    Enum.each(@service_request_seeds, fn spec ->
      seed_service_request!(
        spec,
        facility,
        providers,
        residents,
        relative_users,
        care_team,
        provider_teams
      )
    end)

    IO.puts("  ✓ services: #{length(@service_request_seeds)} requests + messages")
    :ok
  end

  defp seed_service_request!(
         spec,
         facility,
         providers,
         residents,
         relative_users,
         care_team,
         provider_teams
       ) do
    provider = Map.fetch!(providers, spec.provider_kind)

    resident_id =
      case spec.resident do
        {first, last} ->
          case find_resident(residents, {first, last}) do
            %{id: id} -> id
            _ -> nil
          end

        _ ->
          nil
      end

    {requester_user_id, requester_team_id} =
      case spec.requester do
        :relative ->
          user = Enum.at(relative_users, :erlang.phash2(spec.summary, length(relative_users)))
          {user && user.id, nil}

        :care ->
          {nil, care_team.id}
      end

    inserted_at = DateTime.utc_now() |> DateTime.add(-spec.days_ago * 86_400, :second)
    naive = DateTime.to_naive(inserted_at)

    req_id = Ecto.UUID.generate()

    {:ok, _} =
      Caredeck.Repo.query(
        """
        INSERT INTO service_requests
          (id, facility_id, provider_id, resident_id, requester_user_id, requester_team_id,
           subkind, summary, payload, state, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $11)
        """,
        [
          Ecto.UUID.dump!(req_id),
          Ecto.UUID.dump!(facility.id),
          Ecto.UUID.dump!(provider.id),
          (resident_id && Ecto.UUID.dump!(resident_id)) || nil,
          (requester_user_id && Ecto.UUID.dump!(requester_user_id)) || nil,
          (requester_team_id && Ecto.UUID.dump!(requester_team_id)) || nil,
          spec.subkind,
          spec.summary,
          spec.payload,
          to_string(spec.state),
          naive
        ]
      )

    Enum.with_index(spec.messages)
    |> Enum.each(fn {msg, idx} ->
      msg_time = DateTime.add(inserted_at, (idx + 1) * 3_600, :second)
      msg_naive = DateTime.to_naive(msg_time)

      {author_user, author_team} =
        case msg.author do
          :relative ->
            user =
              Enum.at(relative_users, :erlang.phash2({spec.summary, idx}, length(relative_users)))

            {(user && user.id) || requester_user_id, nil}

          :care ->
            {nil, care_team.id}

          :provider ->
            team_handle =
              case spec.provider_kind do
                :pharmacy -> "team-pharmacy"
                :laundry -> "team-laundry"
                :hairdresser -> "team-hairdresser"
                :doctor -> "team-doctor"
                _ -> "team-pharmacy"
              end

            team = Map.get(provider_teams, team_handle)
            {nil, team && team.id}
        end

      {:ok, _} =
        Caredeck.Repo.query(
          """
          INSERT INTO service_messages
            (id, facility_id, service_request_id, author_user_id, author_team_id, body,
             inserted_at, updated_at)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $7)
          """,
          [
            Ecto.UUID.dump!(Ecto.UUID.generate()),
            Ecto.UUID.dump!(facility.id),
            Ecto.UUID.dump!(req_id),
            (author_user && Ecto.UUID.dump!(author_user)) || nil,
            (author_team && Ecto.UUID.dump!(author_team)) || nil,
            msg.body,
            msg_naive
          ]
        )
    end)

    :ok
  end

  @seed_posts [
    %{
      key: :birthday_muller,
      team: "team-care",
      body:
        "Heute war Beatrice Cox' 88. Geburtstag — Schokoladenkuchen, Lieder und viele Gäste. Sie hat sich riesig gefreut!",
      photos: {:feed_birthday, [0, 1, 2]},
      photo_captions: [
        "Beatrice blowing out her 88th candles.",
        "The whole common room joined in for Happy Birthday.",
        "Family card and gifts ready on the table."
      ],
      audience_residents: ["Beatrice", "Cox"],
      tagged_residents: ["Beatrice", "Cox"],
      reactions: 7,
      comment_bodies: [
        "Vielen Dank für die wunderschönen Bilder!",
        "Bitte richten Sie liebe Grüße aus.",
        "Wie schön, sie so glücklich zu sehen ❤"
      ],
      days_ago: 1
    },
    %{
      key: :painting_workshop,
      team: "team-activities",
      body:
        "Group photo from this week's painting workshop — everyone in great spirits. Anika brought new watercolour sets and Maria showed brush technique. Three watercolours headed to the family display wall already.",
      photos: {:feed_painting, [0, 1, 2, 3]},
      photo_captions: [
        "Maria from team-activities helping with brush technique.",
        "Concentration on the watercolour piece.",
        "Finished pieces on display.",
        "Mid-workshop laughter."
      ],
      audience_residents: [{"Constance", "King"}, {"Audrey", "Edwards"}],
      tagged_residents: [{"Constance", "King"}, {"Audrey", "Edwards"}],
      reactions: 4,
      comment_bodies: [
        "Tolles Bild! Mama liebt es zu malen.",
        "Please save one of the watercolours for us to pick up."
      ],
      days_ago: 2
    },
    %{
      key: :physio_hungsinger,
      team: "team-care",
      body:
        "Good news! Mr Hungsinger had a very good report from his physiotherapist today. Range of motion is back to where it was before the fall — Lars is delighted with progress.",
      photos: {:feed_physio, [0, 1, 2]},
      photo_captions: [
        "Lars guiding the arm-raise sequence.",
        "Mid-session — good range now.",
        "Cool-down stretches."
      ],
      audience_residents: [{"Isaac", "Allen"}],
      tagged_residents: [{"Isaac", "Allen"}],
      reactions: 6,
      comment_bodies: [
        "Das ist wundervoll zu hören. Danke an Lars!",
        "We'll bring his favourite blanket on Sunday."
      ],
      days_ago: 1
    },
    %{
      key: :handmotor,
      team: "team-therapy",
      body:
        "Two short clips from today's hand-motor exercises. Constance and Audrey both worked on the peg board — steady improvement week-on-week.",
      photos: {:feed_handmotor, [0, 1]},
      photo_captions: [
        "Therapy putty work.",
        "Peg-board exercise — Constance on the left."
      ],
      audience_residents: [{"Constance", "King"}, {"Audrey", "Edwards"}, {"Isaac", "Allen"}],
      tagged_residents: [{"Constance", "King"}, {"Audrey", "Edwards"}],
      reactions: 3,
      comment_bodies: ["Make sure she does her exercises at home too 😉"],
      days_ago: 3
    },
    %{
      key: :music_therapy,
      team: "team-activities",
      body:
        "Music therapy session this afternoon — Schlager sing-along. Six residents joined, lots of singing. Audio attached if you want to hear.",
      photos: {:feed_music, [0, 1]},
      photo_captions: [
        "Group around the music therapist.",
        "Lieblings-Schlager: Marmor, Stein und Eisen."
      ],
      audio: {:audio, 2},
      audio_caption: "Singing along to a Schlager classic.",
      audience_residents: [
        {"Beatrice", "Cox"},
        {"Penelope", "Davis"},
        {"Edward", "Brooks"},
        {"Isaac", "Allen"},
        {"Ursula", "Hall"}
      ],
      tagged_residents: [{"Beatrice", "Cox"}, {"Edward", "Brooks"}],
      reactions: 8,
      comment_bodies: [
        "Marmor, Stein und Eisen — Mamas Lieblingslied!",
        "Could you share the playlist with us?"
      ],
      days_ago: 2
    },
    %{
      key: :wochenmarkt,
      team: "team-activities",
      body:
        "Wochenmarkt outing today — small group, lots of fresh produce. Constance Rogers picked her own strawberries which are now in the kitchen for tomorrow's breakfast.",
      photos: {:feed_market, [0, 1]},
      photo_captions: [
        "At the produce stand on Karl-Marx-Allee.",
        "Frische Erdbeeren — picked by Constance herself."
      ],
      audience_residents: [
        {"Constance", "Rogers"},
        {"Phyllis", "Lee"},
        {"Doris", "Hall"},
        {"Isaac", "Allen"}
      ],
      tagged_residents: [{"Constance", "Rogers"}, {"Phyllis", "Lee"}],
      reactions: 4,
      comment_bodies: ["Schöne Idee! Mama liebt Erdbeeren."],
      days_ago: 1
    },
    %{
      key: :spargel,
      team: "team-kitchen",
      body:
        "Spargelzeit! Frischer weißer Spargel von einem regionalen Hof — wir servieren ihn diese Woche mit Sauce hollandaise. Wer Spargel mag, bitte beim Pflegeteam anmelden.",
      photos: {:feed_spargel, [0]},
      photo_captions: ["Weißer Spargel from a regional farm — Saturday's main."],
      audience_residents: [],
      tagged_residents: [],
      reactions: 5,
      comment_bodies: [],
      days_ago: 0
    },
    %{
      key: :school_visit,
      team: "team-activities",
      body:
        "Today the Gymnasium am Park visited — eight students from the choir came to sing for the residents. Lots of smiles, a few tears (of joy). They've already asked when they can come back.",
      photos: {:feed_school, [0, 1]},
      photo_captions: [
        "Intergenerational moment.",
        "Choir singing — the students wrote out song sheets in big print."
      ],
      audience_residents: [],
      tagged_residents: [{"Isaac", "Allen"}, {"Edward", "Brooks"}],
      reactions: 8,
      comment_bodies: [
        "Wundervolle Idee, vielen Dank!",
        "Could the choir come for Mum's birthday next month?",
        "Lovely."
      ],
      days_ago: 2
    },
    %{
      key: :garden_walk,
      team: "team-care",
      body:
        "Spaziergang im Garten this morning — three residents joined despite the cool weather. Short video below of the path through the rose garden.",
      photos: {:feed_garden, [0]},
      photo_captions: ["After the walk — sunny corner near the pond."],
      video: {:videos, 1},
      video_caption: "Path through the rose garden.",
      audience_residents: [{"Doris", "Young"}, {"Bernice", "Collins"}, {"Isaac", "Allen"}],
      tagged_residents: [{"Doris", "Young"}, {"Bernice", "Collins"}],
      reactions: 5,
      comment_bodies: [
        "Looks so peaceful 🌹",
        "Dad will love seeing this — thank you for sharing."
      ],
      days_ago: 1
    },
    %{
      key: :new_resident_bauer,
      team: "team-care",
      body:
        "Welcome to Klaus Bauer who moved into Erdgeschoss this week. Klaus loves jazz, chess, and gardening — please say hi if you're visiting. His daughter Anna will be joining the family group.",
      photos: {:feed_welcome, [0]},
      photo_captions: ["Klaus settling into his new room."],
      audience_residents: [],
      tagged_residents: [],
      reactions: 6,
      comment_bodies: [
        "Welcome Klaus! 👋",
        "Schön, jemanden hier zu haben, der gerne Schach spielt."
      ],
      days_ago: 3
    },
    %{
      key: :doctor_internal,
      team: "team-admin",
      body:
        "Quick care-team note — Dr Weber's office confirms Mrs Walker's MDK reassessment is on the books for next Tuesday. Please prep her file in the morning.",
      photos: {:feed_doctor, [0]},
      photo_captions: ["Today's clinical paperwork."],
      is_internal: true,
      audience_residents: [],
      tagged_residents: [{"Mabel", "Martin"}],
      reactions: 0,
      comment_bodies: ["Noted — file will be ready by 09:30."],
      days_ago: 0
    },
    %{
      key: :voice_schlager,
      team: "team-activities",
      body: "Mr Hungsinger entertained the lunch crowd today — short audio clip below. Pure joy.",
      audio: {:audio, 0},
      audio_caption: "Mr Hungsinger humming Marmor, Stein und Eisen.",
      audience_residents: [{"Isaac", "Allen"}],
      tagged_residents: [{"Isaac", "Allen"}],
      reactions: 6,
      comment_bodies: [
        "Wundervoll. Danke fürs Teilen!",
        "We'll bring his Schlager CDs next visit."
      ],
      days_ago: 0
    }
  ]

  defp refresh_feed!(facility) do
    IO.puts("  ↺ rebuilding feed")
    Feed.S3.ensure_bucket!()

    wipe_existing_feed!(facility.id)

    teams_by_handle =
      Accounts.TeamIdentity
      |> Ash.Query.filter(facility_id == ^facility.id)
      |> Ash.read!(authorize?: false)
      |> Map.new(&{to_string(&1.handle), &1})

    residents =
      People.Resident
      |> Ash.read!(tenant: facility.id, authorize?: false)

    relative_users =
      relative_users_with_facility_membership(facility)

    Enum.each(@seed_posts, fn spec ->
      seed_post!(spec, facility, teams_by_handle, residents, relative_users)
    end)

    IO.puts("  ✓ feed rebuilt: #{length(@seed_posts)} posts")
    :ok
  end

  defp wipe_existing_feed!(facility_id) do
    fid = Ecto.UUID.dump!(facility_id)

    sql_tables = [
      "attachments_versions",
      "attachments",
      "comments_versions",
      "comments",
      "reactions_versions",
      "reactions",
      "post_audiences_versions",
      "post_audiences",
      "resident_tags_on_posts_versions",
      "resident_tags_on_posts",
      "posts_versions",
      "posts"
    ]

    Enum.each(sql_tables, fn tbl ->
      {:ok, _} =
        Caredeck.Repo.query("DELETE FROM " <> tbl <> " WHERE facility_id = $1", [fid])
    end)
  end

  defp seed_post!(spec, facility, teams_by_handle, residents, relative_users) do
    team = Map.fetch!(teams_by_handle, spec.team)

    {:ok, post} =
      Feed.Post
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          team_identity_id: team.id,
          body: spec.body,
          is_internal: Map.get(spec, :is_internal, false)
        },
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create(tenant: facility.id, authorize?: false)

    inserted_at =
      DateTime.utc_now() |> DateTime.add(-Map.get(spec, :days_ago, 0) * 86_400, :second)

    backdate!(:posts, post.id, inserted_at)

    Enum.each(spec.audience_residents, fn match ->
      case find_resident(residents, match) do
        nil ->
          :ok

        r ->
          Feed.PostAudience
          |> Ash.Changeset.for_create(
            :create,
            %{facility_id: facility.id, post_id: post.id, resident_id: r.id},
            tenant: facility.id,
            authorize?: false
          )
          |> Ash.create!(tenant: facility.id, authorize?: false)
      end
    end)

    Enum.each(spec.tagged_residents, fn match ->
      case find_resident(residents, match) do
        nil ->
          :ok

        r ->
          Feed.ResidentTagOnPost
          |> Ash.Changeset.for_create(
            :create,
            %{facility_id: facility.id, post_id: post.id, resident_id: r.id},
            tenant: facility.id,
            authorize?: false
          )
          |> Ash.create!(tenant: facility.id, authorize?: false)
      end
    end)

    case Map.get(spec, :photos) do
      {group, indices} ->
        captions = Map.get(spec, :photo_captions, [])

        Enum.with_index(indices)
        |> Enum.each(fn {idx, position} ->
          path = Caredeck.Release.Assets.at(group, idx)
          meta = Caredeck.Release.Assets.upload_with_meta!(path)
          caption = Enum.at(captions, position)

          Feed.Attachment
          |> Ash.Changeset.for_create(
            :create,
            %{
              facility_id: facility.id,
              post_id: post.id,
              kind: :photo,
              s3_key: meta.s3_key,
              thumbnail_s3_key: meta.s3_key,
              mime_type: meta.mime_type,
              bytes: meta.bytes,
              caption: caption,
              position: position
            },
            tenant: facility.id,
            authorize?: false
          )
          |> Ash.create!(tenant: facility.id, authorize?: false)
        end)

      _ ->
        :ok
    end

    case Map.get(spec, :video) do
      {group, idx} ->
        video_path = Caredeck.Release.Assets.at(group, idx)
        video_meta = Caredeck.Release.Assets.upload_with_meta!(video_path)
        poster_path = Caredeck.Release.Assets.video_poster_path(video_path)
        poster_meta = Caredeck.Release.Assets.upload_with_meta!(poster_path)

        Feed.Attachment
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: facility.id,
            post_id: post.id,
            kind: :video,
            s3_key: video_meta.s3_key,
            thumbnail_s3_key: poster_meta.s3_key,
            mime_type: video_meta.mime_type,
            bytes: video_meta.bytes,
            duration_sec: video_meta.duration_sec,
            caption: Map.get(spec, :video_caption),
            position: 99
          },
          tenant: facility.id,
          authorize?: false
        )
        |> Ash.create!(tenant: facility.id, authorize?: false)

      _ ->
        :ok
    end

    case Map.get(spec, :audio) do
      {group, idx} ->
        path = Caredeck.Release.Assets.at(group, idx)
        meta = Caredeck.Release.Assets.upload_with_meta!(path)

        Feed.Attachment
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: facility.id,
            post_id: post.id,
            kind: :audio,
            s3_key: meta.s3_key,
            mime_type: meta.mime_type,
            bytes: meta.bytes,
            duration_sec: meta.duration_sec,
            caption: Map.get(spec, :audio_caption),
            position: 98
          },
          tenant: facility.id,
          authorize?: false
        )
        |> Ash.create!(tenant: facility.id, authorize?: false)

      _ ->
        :ok
    end

    seed_reactions!(post, facility, relative_users, Map.get(spec, :reactions, 0))

    seed_comments!(
      post,
      facility,
      relative_users,
      Map.get(spec, :comment_bodies, []),
      inserted_at
    )

    :ok
  end

  defp seed_reactions!(_post, _facility, [], _n), do: :ok
  defp seed_reactions!(_post, _facility, _users, 0), do: :ok

  defp seed_reactions!(post, facility, users, n) do
    users
    |> Enum.sort_by(&:erlang.phash2({post.id, &1.id}))
    |> Enum.take(n)
    |> Enum.each(fn user ->
      kind = if rem(:erlang.phash2({post.id, user.id}), 10) < 3, do: :heart, else: :like

      Feed.Reaction
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility.id,
          post_id: post.id,
          user_id: user.id,
          kind: kind
        },
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility.id, authorize?: false)
    end)
  end

  defp seed_comments!(_post, _facility, [], _bodies, _base), do: :ok
  defp seed_comments!(_post, _facility, _users, [], _base), do: :ok

  defp seed_comments!(post, facility, users, bodies, base_time) do
    users
    |> Enum.sort_by(&:erlang.phash2({post.id, :comment, &1.id}))
    |> Enum.take(length(bodies))
    |> Enum.with_index()
    |> Enum.each(fn {user, idx} ->
      body = Enum.at(bodies, idx)
      ts = DateTime.add(base_time, idx * 600, :second)

      {:ok, comment} =
        Feed.Comment
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: facility.id,
            post_id: post.id,
            author_user_id: user.id,
            body: body
          },
          tenant: facility.id,
          authorize?: false
        )
        |> Ash.create(tenant: facility.id, authorize?: false)

      backdate!(:comments, comment.id, ts)
    end)
  end

  defp backdate!(table, id, %DateTime{} = ts) do
    naive = DateTime.to_naive(ts)

    {:ok, _} =
      Caredeck.Repo.query(
        "UPDATE #{table} SET inserted_at = $1, updated_at = $1 WHERE id = $2",
        [naive, Ecto.UUID.dump!(id)]
      )
  end

  defp find_resident(residents, {first, last}) do
    Enum.find(residents, fn r ->
      r.first_name == first and r.last_name == last
    end)
  end

  defp find_resident(residents, [first | _rest]), do: find_resident(residents, {first, ""})

  defp find_resident(_residents, _), do: nil

  defp relative_users_with_facility_membership(facility) do
    case Caredeck.Org.FacilityMembership
         |> Ash.Query.filter(facility_id == ^facility.id)
         |> Ash.read(authorize?: false) do
      {:ok, memberships} ->
        user_ids = Enum.map(memberships, & &1.user_id) |> Enum.uniq()

        Caredeck.Accounts.User
        |> Ash.Query.filter(id in ^user_ids)
        |> Ash.read!(authorize?: false)

      _ ->
        []
    end
  end

  @team_avatar_map %{
    "team-admin" => 0,
    "team-care" => 1,
    "team-activities" => 2,
    "team-therapy" => 3,
    "team-kitchen" => 4,
    "team-pharmacy" => 5,
    "team-laundry" => 6,
    "team-hairdresser" => 7,
    "team-doctor" => 8
  }

  defp refresh_avatars!(facility) do
    IO.puts("  ↺ uploading + assigning avatars")

    Enum.each(@team_avatar_map, fn {handle, idx} ->
      case Accounts.TeamIdentity
           |> Ash.Query.filter(handle == ^handle and facility_id == ^facility.id)
           |> Ash.read_one(authorize?: false) do
        {:ok, %{} = team} ->
          key = Caredeck.Release.Assets.upload!(Caredeck.Release.Assets.at(:avatars_team, idx))

          team
          |> Ash.Changeset.for_update(:update, %{avatar_url: key}, authorize?: false)
          |> Ash.update!(authorize?: false)

        _ ->
          :ok
      end
    end)

    residents =
      People.Resident
      |> Ash.Query.sort(inserted_at: :asc)
      |> Ash.Query.limit(15)
      |> Ash.read!(tenant: facility.id, authorize?: false)

    Enum.with_index(residents)
    |> Enum.each(fn {resident, idx} ->
      key = Caredeck.Release.Assets.upload!(Caredeck.Release.Assets.at(:avatars_resident, idx))

      resident
      |> Ash.Changeset.for_update(:update, %{avatar_url: key},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.update!(tenant: facility.id, authorize?: false)
    end)

    relatives =
      People.Relative
      |> Ash.Query.sort(inserted_at: :asc)
      |> Ash.Query.limit(20)
      |> Ash.read!(tenant: facility.id, authorize?: false)

    Enum.with_index(relatives)
    |> Enum.each(fn {relative, idx} ->
      key = Caredeck.Release.Assets.upload!(Caredeck.Release.Assets.at(:avatars_relative, idx))

      relative
      |> Ash.Changeset.for_update(:update, %{avatar_url: key},
        tenant: facility.id,
        authorize?: false
      )
      |> Ash.update!(tenant: facility.id, authorize?: false)
    end)

    IO.puts(
      "  ✓ avatars: #{length(residents)} residents, #{length(relatives)} relatives, #{map_size(@team_avatar_map)} teams"
    )

    :ok
  end

  defp rematerialise_kitchen_days!(facility) do
    dates =
      Kitchen.DayMenu
      |> Ash.read!(tenant: facility.id, authorize?: false)
      |> Enum.map(& &1.date)
      |> Enum.sort()

    IO.puts("  ↺ rematerialising #{length(dates)} kitchen day(s): #{inspect(dates)}")

    {:ok, _} =
      Caredeck.Repo.query(
        "DELETE FROM kitchen_day_menu_slots_versions WHERE facility_id = $1",
        [Ecto.UUID.dump!(facility.id)]
      )

    {:ok, _} =
      Caredeck.Repo.query(
        "DELETE FROM kitchen_day_menus_versions WHERE facility_id = $1",
        [Ecto.UUID.dump!(facility.id)]
      )

    {:ok, _} =
      Caredeck.Repo.query("DELETE FROM kitchen_day_menu_slots WHERE facility_id = $1", [
        Ecto.UUID.dump!(facility.id)
      ])

    {:ok, _} =
      Caredeck.Repo.query("DELETE FROM kitchen_day_menus WHERE facility_id = $1", [
        Ecto.UUID.dump!(facility.id)
      ])

    Enum.each(dates, fn date ->
      Kitchen.Materialise.materialise_day(facility.id, date)
    end)

    :ok
  end

  defp refresh_application!(app, admin, facility) do
    user =
      case app.applicant_user_id do
        nil ->
          nil

        id ->
          Accounts.User
          |> Ash.Query.filter(id == ^id)
          |> Ash.read_one(authorize?: false)
          |> case do
            {:ok, u} -> u
            _ -> nil
          end
      end

    prefill_person_needing_care!(app, app.resident, facility)
    if user, do: prefill_applicant!(app, user, facility)

    Formfix.ApplicationNote
    |> Ash.Query.filter(application_id == ^app.id)
    |> Ash.read!(tenant: facility.id, authorize?: false)
    |> Enum.each(&Ash.destroy!(&1, tenant: facility.id, authorize?: false))

    if admin, do: ensure_demo_notes!(app, admin, facility)

    :ok
  end

  defp refresh_kitchen_slots!(facility) do
    template =
      Kitchen.MenuTemplate
      |> Ash.Query.filter(is_active == true)
      |> Ash.read_one(tenant: facility.id, authorize?: false)
      |> case do
        {:ok, %{} = t} ->
          t

        _ ->
          Kitchen.MenuTemplate
          |> Ash.Changeset.for_create(
            :create,
            %{facility_id: facility.id, name: "Default week", is_active: true},
            tenant: facility.id,
            authorize?: false
          )
          |> Ash.create!(tenant: facility.id, authorize?: false)
      end

    {:ok, _} =
      Caredeck.Repo.query(
        "DELETE FROM kitchen_menu_template_slots_versions WHERE facility_id = $1",
        [Ecto.UUID.dump!(facility.id)]
      )

    {:ok, _} =
      Caredeck.Repo.query(
        "DELETE FROM kitchen_menu_template_slots WHERE menu_template_id = $1",
        [Ecto.UUID.dump!(template.id)]
      )

    products =
      Enum.flat_map(@kitchen_products, fn {cat, names} ->
        Enum.map(names, fn name ->
          find_or_create_product(facility, cat, name)
        end)
      end)

    product_by_category = Enum.group_by(products, & &1.category)

    for {day, day_index} <- Enum.with_index(@kitchen_days_order),
        cat <- Kitchen.MealCategory.all() do
      category_products = Map.fetch!(product_by_category, cat)
      product = Enum.at(category_products, rem(day_index, length(category_products)))

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

    :ok
  end

  defp find_or_create_product(facility, category, name) do
    case Kitchen.Product
         |> Ash.Query.filter(category == ^category and name == ^name)
         |> Ash.read_one(tenant: facility.id, authorize?: false) do
      {:ok, %{} = p} ->
        p

      _ ->
        Kitchen.Product
        |> Ash.Changeset.for_create(
          :create,
          %{facility_id: facility.id, name: name, category: category, is_default: true},
          tenant: facility.id,
          authorize?: false
        )
        |> Ash.create!(tenant: facility.id, authorize?: false)
    end
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
        |> Ash.Query.filter(
          state in [:draft, :missing_documents, :ready_to_submit, :submitted, :approved]
        )
        |> Ash.read!(tenant: facility.id, authorize?: false)
        |> Enum.each(&ensure_demo_notes!(&1, admin, facility))
    end
  end

  @demo_note_pool [
    ["Reviewed initial submission — sections look complete.", "Documents verified by counsel."],
    [
      "Applicant called, requesting an update on the decision.",
      "MDK assessment scheduled for next week."
    ],
    [
      "Income proof received, attaching to file.",
      "Pflegegrad 3 confirmed; escalating to Pflegegrad 4."
    ],
    [
      "Returned for amendments — missing partner's pension statement.",
      "Re-uploaded missing docs, ready for re-review."
    ],
    [
      "Awaiting case-worker sign-off.",
      "Discussed with MDK contact, decision expected within 4 weeks."
    ]
  ]

  defp ensure_demo_notes!(app, admin, facility) do
    existing =
      Formfix.ApplicationNote
      |> Ash.Query.filter(application_id == ^app.id)
      |> Ash.read!(tenant: facility.id, authorize?: false)

    if existing == [] do
      idx = :erlang.phash2(app.id, length(@demo_note_pool))
      bodies = Enum.at(@demo_note_pool, idx)

      Enum.each(bodies, fn body ->
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
      end)
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

  @demo_addresses [
    %{postal_code: "10115", street: "Invalidenstraße 12", city: "Berlin"},
    %{postal_code: "10243", street: "Karl-Marx-Allee 84", city: "Berlin"},
    %{postal_code: "10999", street: "Oranienstraße 41", city: "Berlin"},
    %{postal_code: "12047", street: "Hermannstraße 217", city: "Berlin"},
    %{postal_code: "13409", street: "Residenzstraße 50", city: "Berlin"}
  ]

  defp prefill_person_needing_care!(application, resident, facility) do
    addr = pick_demo_address(resident)
    dob = resident.date_of_birth || ~D[1942-03-15]

    Formfix.SectionWriter.save_answers!(application, :person_needing_care, %{
      "first_name" => resident.first_name,
      "last_name" => resident.last_name,
      "date_of_birth" => Date.to_iso8601(dob),
      "birth_place" => addr.city,
      "marital_status" => "widowed",
      "postal_code" => addr.postal_code,
      "street" => addr.street,
      "city" => addr.city
    })

    _ = facility
    :ok
  end

  defp pick_demo_address(resident) do
    idx = :erlang.phash2(resident.id, length(@demo_addresses))
    Enum.at(@demo_addresses, idx)
  end

  defp prefill_applicant!(application, user, facility) do
    Formfix.SectionWriter.save_answers!(application, :applicant, %{
      "first_name" => user.name || "Demo",
      "last_name" => user.family_name || "Relative"
    })

    _ = facility
    :ok
  end

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

      for {day, day_index} <- Enum.with_index(@kitchen_days_order),
          cat <- Kitchen.MealCategory.all() do
        category_products = Map.fetch!(product_by_category, cat)
        product = Enum.at(category_products, rem(day_index, length(category_products)))

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
    facility =
      find_or_create(
        Org.Facility |> Ash.Query.filter(slug == "sandbox-home"),
        Org.Facility,
        %{district_id: district.id, name: "Spring Hill Care Home", slug: "sandbox-home"}
      )

    if facility.name != "Spring Hill Care Home" do
      facility
      |> Ash.Changeset.for_update(:update, %{name: "Spring Hill Care Home"}, authorize?: false)
      |> Ash.update!(authorize?: false)
    else
      facility
    end
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

      {:ok, %{name: current_name} = existing} when current_name != name ->
        existing
        |> Ash.Changeset.for_update(:update, %{name: name}, authorize?: false)
        |> Ash.update!(authorize?: false)

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
