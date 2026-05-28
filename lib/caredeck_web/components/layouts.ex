defmodule CaredeckWeb.Layouts do
  use CaredeckWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :current_user, :map, default: nil
  attr :current_team, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="border-b border-divider bg-card">
      <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
        <a href="/" class="flex items-center">
          <img src={~p"/images/brand/caredeck-lockup.svg"} alt="Caredeck" height="32" class="h-8" />
        </a>
        <nav class="flex items-center gap-6 text-sm text-ink-500">
          <a href="/design-system" class="hover:text-ink-900">Design System</a>
          <span :if={@current_user} class="text-ink-900">{@current_user.email}</span>
          <.link
            :if={@current_user}
            href={~p"/sign-out"}
            method="delete"
            class="hover:text-ink-900"
          >
            Sign out
          </.link>
          <span :if={@current_team} class="text-ink-900">{@current_team.name}</span>
          <.link :if={@current_team} href={~p"/team/sign-out"} class="hover:text-ink-900">
            Sign out
          </.link>
        </nav>
      </div>
    </header>

    <main class="bg-page min-h-[calc(100vh-65px)]">
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end
end
