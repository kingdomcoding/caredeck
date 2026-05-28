defmodule CaredeckWeb.AcceptInvitationLive do
  use CaredeckWeb, :live_view

  alias Caredeck.{Accounts, Org, People}
  alias Caredeck.People.RelativeInvitation

  require Ash.Query

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case RelativeInvitation.verify_token(token) do
      {:ok, invitation_id} ->
        case load_invitation(invitation_id) do
          {:ok, invitation, resident} ->
            existing_user = find_user(invitation.email)

            {:ok,
             socket
             |> assign(:invitation, invitation)
             |> assign(:resident, resident)
             |> assign(:existing_user, existing_user)
             |> assign(:relationship, to_string(invitation.suggested_relationship || ""))
             |> assign(:error, nil)
             |> assign(:page_title, "Accept invitation")}

          :expired ->
            {:ok,
             socket
             |> put_flash(:error, "Invitation expired or already used.")
             |> redirect(to: ~p"/sign-in")}

          :not_found ->
            {:ok,
             socket
             |> put_flash(:error, "Invitation link is invalid.")
             |> redirect(to: ~p"/sign-in")}
        end

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Invitation link is invalid.")
         |> redirect(to: ~p"/sign-in")}
    end
  end

  defp load_invitation(invitation_id) do
    facilities = Caredeck.Org.Facility |> Ash.read!(authorize?: false)

    Enum.reduce_while(facilities, :not_found, fn facility, _acc ->
      case Ash.get(RelativeInvitation, invitation_id,
             tenant: facility.id,
             authorize?: false
           ) do
        {:ok, %{accepted_at: nil} = invitation} ->
          {:halt,
           {:ok, invitation,
            Ash.get!(People.Resident, invitation.resident_id,
              tenant: facility.id,
              authorize?: false
            )}}

        {:ok, _accepted} ->
          {:halt, :expired}

        _ ->
          {:cont, :not_found}
      end
    end)
  end

  defp find_user(email) do
    case Ash.read_one(
           Accounts.User |> Ash.Query.filter(email == ^email),
           authorize?: false
         ) do
      {:ok, %{} = u} -> u
      _ -> nil
    end
  end

  @impl true
  def handle_event("accept", params, socket) do
    invitation = socket.assigns.invitation
    facility_id = invitation.facility_id

    relationship =
      case Map.get(params, "relationship", "") do
        "" -> :other
        s -> String.to_existing_atom(s)
      end

    with {:ok, user} <- ensure_user(socket.assigns.existing_user, invitation, params),
         {:ok, relative} <- ensure_relative(user, invitation, params),
         :ok <- ensure_membership(user, facility_id),
         :ok <- ensure_relationship(relative, invitation.resident_id, relationship, facility_id),
         {:ok, _} <- mark_accepted(invitation) do
      {:noreply,
       socket
       |> put_flash(:info, "Welcome to Caredeck. Please sign in to continue.")
       |> redirect(to: ~p"/sign-in")}
    else
      {:error, err} ->
        {:noreply, assign(socket, :error, format_error(err))}
    end
  end

  defp ensure_user(%Accounts.User{} = u, _invitation, _params), do: {:ok, u}

  defp ensure_user(nil, invitation, params) do
    Accounts.User
    |> Ash.Changeset.for_create(
      :register_with_password,
      %{
        email: to_string(invitation.email),
        name: params["first_name"],
        family_name: params["family_name"],
        password: params["password"],
        password_confirmation: params["password"]
      },
      authorize?: false
    )
    |> Ash.create()
    |> case do
      {:ok, user} ->
        user
        |> Ash.Changeset.for_update(:update_profile, %{}, authorize?: false)
        |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
        |> Ash.update()

      err ->
        err
    end
  end

  defp ensure_relative(user, invitation, params) do
    display_name =
      "#{String.trim(params["first_name"] || "")} #{String.trim(params["family_name"] || "")}"
      |> String.trim()

    case Ash.read_one(
           People.Relative |> Ash.Query.filter(user_id == ^user.id),
           tenant: invitation.facility_id,
           authorize?: false
         ) do
      {:ok, %{} = relative} ->
        {:ok, relative}

      _ ->
        People.Relative
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: invitation.facility_id,
            user_id: user.id,
            display_name: display_name,
            phone: params["phone"]
          },
          tenant: invitation.facility_id,
          authorize?: false
        )
        |> Ash.create()
    end
  end

  defp ensure_membership(user, facility_id) do
    case Ash.read_one(
           Org.FacilityMembership
           |> Ash.Query.filter(user_id == ^user.id and facility_id == ^facility_id),
           authorize?: false
         ) do
      {:ok, nil} ->
        Org.FacilityMembership
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: facility_id,
            user_id: user.id,
            role: :relative,
            source: :invited
          },
          authorize?: false
        )
        |> Ash.create()
        |> case do
          {:ok, _} -> :ok
          err -> err
        end

      _ ->
        :ok
    end
  end

  defp ensure_relationship(relative, resident_id, relationship, facility_id) do
    case Ash.read_one(
           People.RelativeOfResident
           |> Ash.Query.filter(relative_id == ^relative.id and resident_id == ^resident_id),
           tenant: facility_id,
           authorize?: false
         ) do
      {:ok, %{}} ->
        :ok

      _ ->
        People.RelativeOfResident
        |> Ash.Changeset.for_create(
          :create,
          %{
            facility_id: facility_id,
            relative_id: relative.id,
            resident_id: resident_id,
            relationship: relationship
          },
          tenant: facility_id,
          authorize?: false
        )
        |> Ash.create()
        |> case do
          {:ok, _} -> :ok
          err -> err
        end
    end
  end

  defp mark_accepted(invitation) do
    invitation
    |> Ash.Changeset.for_update(:accept, %{},
      tenant: invitation.facility_id,
      authorize?: false
    )
    |> Ash.update(tenant: invitation.facility_id, authorize?: false)
  end

  defp format_error(err) when is_binary(err), do: err

  defp format_error(%{errors: errors}) do
    case errors do
      [%{message: m} | _] -> m
      _ -> "Could not accept invitation."
    end
  end

  defp format_error(_), do: "Could not accept invitation."

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_team={@current_team}
    >
      <div class="mx-auto max-w-md px-4 py-6">
        <h1 class="text-display-md text-ink-900 mb-2">Join Caredeck</h1>
        <p class="text-ink-500 mb-4">
          You've been invited to follow {@resident.first_name} {@resident.last_name}.
        </p>

        <form phx-submit="accept" class="space-y-4">
          <label class="block">
            <span class="text-ink-900 text-sm font-medium">Email</span>
            <input
              type="email"
              value={to_string(@invitation.email)}
              readonly
              class="mt-1 block w-full rounded-input border border-divider px-3 py-2 text-ink-900 bg-page text-ink-500"
            />
          </label>

          <div :if={!@existing_user} class="space-y-4">
            <div class="grid grid-cols-2 gap-3">
              <label class="block">
                <span class="text-ink-900 text-sm font-medium">First name</span>
                <input
                  type="text"
                  name="first_name"
                  required
                  class="mt-1 block w-full rounded-input border border-divider px-3 py-2 text-ink-900"
                />
              </label>
              <label class="block">
                <span class="text-ink-900 text-sm font-medium">Family name</span>
                <input
                  type="text"
                  name="family_name"
                  required
                  class="mt-1 block w-full rounded-input border border-divider px-3 py-2 text-ink-900"
                />
              </label>
            </div>

            <label class="block">
              <span class="text-ink-900 text-sm font-medium">Password</span>
              <input
                type="password"
                name="password"
                required
                minlength="8"
                class="mt-1 block w-full rounded-input border border-divider px-3 py-2 text-ink-900"
              />
            </label>

            <label class="block">
              <span class="text-ink-900 text-sm font-medium">Phone (optional)</span>
              <input
                type="tel"
                name="phone"
                class="mt-1 block w-full rounded-input border border-divider px-3 py-2 text-ink-900"
              />
            </label>
          </div>

          <p :if={@existing_user} class="text-ink-500 text-sm">
            You already have a Caredeck account. We'll add you to the family for {@resident.first_name}.
          </p>

          <label class="block">
            <span class="text-ink-900 text-sm font-medium">
              Relationship to {@resident.first_name}
            </span>
            <select
              name="relationship"
              required
              class="mt-1 block w-full rounded-input border border-divider px-3 py-2 text-ink-900 bg-card"
            >
              <%= for {value, label} <- relationship_options() do %>
                <option value={value} selected={@relationship == value}>{label}</option>
              <% end %>
            </select>
          </label>

          <p :if={@error} class="text-red-600 text-sm">{@error}</p>

          <button type="submit" class="w-full rounded-button bg-brand text-white px-4 py-2">
            Accept &amp; continue
          </button>
        </form>
      </div>
    </Layouts.app>
    """
  end

  defp relationship_options do
    [
      {"daughter", "Daughter"},
      {"son", "Son"},
      {"niece", "Niece"},
      {"nephew", "Nephew"},
      {"granddaughter", "Granddaughter"},
      {"grandson", "Grandson"},
      {"wife", "Wife"},
      {"husband", "Husband"},
      {"spouse", "Spouse"},
      {"partner", "Partner"},
      {"sibling", "Sibling"},
      {"legal_guardian", "Legal guardian"},
      {"other", "Other"}
    ]
  end
end
