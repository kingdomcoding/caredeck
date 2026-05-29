defmodule CaredeckWeb.Services.RequestLive do
  use CaredeckWeb, :live_view

  alias Caredeck.Services.ServiceRequest

  @impl true
  def mount(%{"request_id" => rid}, _session, socket) do
    facility = socket.assigns[:current_facility]
    actor = current_actor(socket)

    cond do
      is_nil(facility) ->
        {:ok, push_navigate(socket, to: ~p"/feed")}

      true ->
        case Ash.get(ServiceRequest, rid,
               tenant: facility.id,
               actor: actor,
               load: [:provider, :resident]
             ) do
          {:ok, request} ->
            {:ok,
             socket
             |> assign(:page_title, request.summary || request.subkind)
             |> assign(:request, request)}

          _ ->
            {:ok, push_navigate(socket, to: ~p"/services")}
        end
    end
  end

  defp current_actor(socket),
    do: socket.assigns[:current_team] || socket.assigns[:current_user]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-2xl px-4 sm:px-6 py-6">
        <p class="text-ink-500 text-xs uppercase tracking-wide">
          {@request.provider.name}
        </p>
        <h1 class="text-display-sm text-ink-900 mb-2">
          {@request.summary || @request.subkind}
        </h1>
        <p class="text-ink-500 text-sm">
          Created {Calendar.strftime(@request.inserted_at, "%d %b %Y · %H:%M")}
        </p>
        <p class="text-ink-500 text-sm mt-4">
          Full request view ships on Day 4.
        </p>
      </div>
    </Layouts.app>
    """
  end
end
