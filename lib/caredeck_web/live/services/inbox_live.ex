defmodule CaredeckWeb.Services.InboxLive do
  use CaredeckWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Services inbox")
     |> push_navigate(to: ~p"/services")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_team={@current_team}>
      <div class="mx-auto max-w-4xl px-4 sm:px-6 py-6">
        <h1 class="text-display-md text-ink-900">Services inbox</h1>
        <p class="text-ink-500 text-sm">Ships on Day 4.</p>
      </div>
    </Layouts.app>
    """
  end
end
