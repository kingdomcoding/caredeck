defmodule CaredeckWeb.DesignSystemLive do
  use CaredeckWeb, :live_view

  @teal_swatches [
    {"50", "bg-teal-50"},
    {"100", "bg-teal-100"},
    {"200", "bg-teal-200"},
    {"300", "bg-teal-300"},
    {"400", "bg-teal-400"},
    {"500", "bg-teal-500"},
    {"600", "bg-teal-600"},
    {"700", "bg-teal-700"},
    {"800", "bg-teal-800"},
    {"900", "bg-teal-900"}
  ]

  @status_badges [
    {"Draft", "bg-status-draft-bg border-status-draft-border text-status-draft-text"},
    {"Missing Documents",
     "bg-status-missing-bg border-status-missing-border text-status-missing-text"},
    {"Ready to Submit", "bg-status-ready-bg border-status-ready-border text-status-ready-text"},
    {"Submitted",
     "bg-status-submitted-bg border-status-submitted-border text-status-submitted-text"},
    {"Approved", "bg-status-approved-bg border-status-approved-border text-status-approved-text"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:teal_swatches, @teal_swatches)
     |> assign(:status_badges, @status_badges)
     |> assign(:page_title, "Design System")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl px-6 py-12 space-y-16">
        <section>
          <h1 class="text-display-md text-ink-900">Caredeck Design System</h1>
          <p class="text-ink-500 mt-2">
            Living style guide. Edit
            <code class="rounded bg-page px-1 py-0.5 text-ink-700">assets/css/app.css</code>
            and refresh — this page reflects every token.
          </p>
        </section>

        <section>
          <h2 class="text-display-sm text-ink-900 mb-4">Brand teal</h2>
          <div class="grid grid-cols-5 sm:grid-cols-10 gap-2">
            <div :for={{label, swatch_class} <- @teal_swatches} class="flex flex-col">
              <div class={["h-16 rounded-md border border-divider", swatch_class]} />
              <span class="text-xs text-ink-500 mt-1">teal-{label}</span>
            </div>
          </div>
        </section>

        <section>
          <h2 class="text-display-sm text-ink-900 mb-4">Aid status badges</h2>
          <div class="flex flex-wrap gap-3">
            <span
              :for={{label, badge_class} <- @status_badges}
              class={[
                "inline-flex items-center px-3 py-1 text-sm font-medium rounded-chip border",
                badge_class
              ]}
            >
              {label}
            </span>
          </div>
        </section>

        <section>
          <h2 class="text-display-sm text-ink-900 mb-4">Typography</h2>
          <div class="space-y-3">
            <p class="text-display-xl">Display XL</p>
            <p class="text-display-lg">Display LG</p>
            <p class="text-display-md">Display MD</p>
            <p class="text-display-sm">Display SM</p>
            <p class="text-base text-ink-700">Body — the quick brown fox.</p>
            <p class="text-sm text-ink-500">Caption — the quick brown fox.</p>
          </div>
        </section>

        <section>
          <h2 class="text-display-sm text-ink-900 mb-4">Cards &amp; radii</h2>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 items-start">
            <div class="bg-card rounded-card shadow-card p-6">
              <p class="text-ink-900 font-medium">Feed card</p>
              <p class="text-ink-500 text-sm">rounded-card · shadow-card</p>
            </div>
            <button
              type="button"
              class="rounded-button bg-brand text-white px-4 py-2 font-medium hover:bg-teal-600"
            >
              Primary button
            </button>
            <div class="flex items-center justify-center">
              <div class="rounded-fab bg-brand text-white w-14 h-14 flex items-center justify-center shadow-fab text-sm font-semibold">
                NEW
              </div>
            </div>
          </div>
        </section>

        <section>
          <h2 class="text-display-sm text-ink-900 mb-4">Like &amp; engagement</h2>
          <p class="text-ink-700 flex items-center gap-2">
            <.icon name="hero-heart-solid" class="w-5 h-5 text-like-red" />
            <span class="font-medium">9 likes</span>
            <span class="text-ink-500 mx-1">·</span>
            <.icon name="hero-chat-bubble-oval-left" class="w-5 h-5 text-ink-500" />
            <span class="text-ink-500">6 comments</span>
          </p>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
