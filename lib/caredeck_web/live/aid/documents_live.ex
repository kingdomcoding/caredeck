defmodule CaredeckWeb.Aid.DocumentsLive do
  use CaredeckWeb, :live_view

  @impl true
  def mount(%{"application_id" => aid}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Required documents")
     |> assign(:application_id, aid)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-3xl px-4 sm:px-6 py-6">
        <.aid_back_link application_id={@application_id} />
        <p class="text-ink-500 text-sm">Documents page ships on Day 5.</p>
        <.aid_footer />
      </div>
    </Layouts.app>
    """
  end
end
