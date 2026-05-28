defmodule CaredeckWeb.PostLive do
  use CaredeckWeb, :live_view

  @impl true
  def mount(%{"post_id" => _id}, _session, socket) do
    {:ok, assign(socket, :page_title, "Post")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_team={@current_team}
    >
      <div class="mx-auto max-w-2xl px-4 py-6">
        <h1 class="text-display-md">Post detail (Day 6)</h1>
      </div>
    </Layouts.app>
    """
  end
end
