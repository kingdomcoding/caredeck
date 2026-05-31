defmodule CaredeckWeb.Icons do
  use Phoenix.Component

  attr :name, :atom, required: true
  attr :class, :string, default: "h-5 w-5"
  attr :rest, :global

  def icon(%{name: :lock} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      class={@class}
      aria-hidden="true"
      {@rest}
    >
      <rect x="5" y="11" width="14" height="9" rx="2" />
      <path stroke-linecap="round" d="M8 11V8a4 4 0 0 1 8 0v3" />
    </svg>
    """
  end

  def icon(%{name: :bell} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      class={@class}
      aria-hidden="true"
      {@rest}
    >
      <path stroke-linecap="round" stroke-linejoin="round" d="M6 8a6 6 0 0 1 12 0v5l2 2H4l2-2z" />
      <path stroke-linecap="round" d="M10 19a2 2 0 0 0 4 0" />
    </svg>
    """
  end

  def icon(%{name: :plus} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      class={@class}
      aria-hidden="true"
      {@rest}
    >
      <path stroke-linecap="round" d="M12 5v14M5 12h14" />
    </svg>
    """
  end

  def icon(%{name: :heart} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="currentColor"
      class={@class}
      aria-hidden="true"
      {@rest}
    >
      <path d="M12 21s-7-4.35-7-10a4 4 0 0 1 7-2.65A4 4 0 0 1 19 11c0 5.65-7 10-7 10z" />
    </svg>
    """
  end

  def icon(%{name: :heart_outline} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      class={@class}
      aria-hidden="true"
      {@rest}
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M12 21s-7-4.35-7-10a4 4 0 0 1 7-2.65A4 4 0 0 1 19 11c0 5.65-7 10-7 10z"
      />
    </svg>
    """
  end

  def icon(%{name: :comment} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      class={@class}
      aria-hidden="true"
      {@rest}
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M4 5h16a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H8l-4 4V6a1 1 0 0 1 1-1z"
      />
    </svg>
    """
  end

  def icon(%{name: :pill} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.75"
      class={@class}
      aria-hidden="true"
      {@rest}
    >
      <rect x="2.5" y="9" width="19" height="6" rx="3" transform="rotate(-30 12 12)" />
      <path d="M9.5 6.5l8 8" />
    </svg>
    """
  end

  def icon(%{name: :scissors} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.75"
      class={@class}
      aria-hidden="true"
      {@rest}
    >
      <circle cx="6" cy="6" r="3" />
      <circle cx="6" cy="18" r="3" />
      <path d="M8.5 8.5L20 20M8.5 15.5L20 4" stroke-linecap="round" />
    </svg>
    """
  end

  def icon(%{name: :stethoscope} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.75"
      class={@class}
      aria-hidden="true"
      {@rest}
    >
      <path stroke-linecap="round" d="M6 3v6a5 5 0 0 0 10 0V3" />
      <path stroke-linecap="round" d="M4 3h2M16 3h2" />
      <path stroke-linecap="round" d="M11 14v3a4 4 0 0 0 8 0v-1" />
      <circle cx="19" cy="14" r="2" />
    </svg>
    """
  end

  def icon(%{name: :basket} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.75"
      class={@class}
      aria-hidden="true"
      {@rest}
    >
      <path stroke-linecap="round" stroke-linejoin="round" d="M3 9h18l-2 11H5L3 9z" />
      <path stroke-linecap="round" d="M8 9l4-6 4 6" />
    </svg>
    """
  end

  def icon(%{name: :foot} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.75"
      class={@class}
      aria-hidden="true"
      {@rest}
    >
      <path stroke-linecap="round" stroke-linejoin="round" d="M9 21c-2 0-3-2-3-4 0-1 .5-2 .5-3 0-2-1.5-3-1.5-6 0-3 2-6 5-6s4 2 4 5c0 4-1 5-1 8 0 4-2 6-4 6z" />
      <circle cx="14" cy="6" r="1.2" />
      <circle cx="16.5" cy="8" r="1" />
      <circle cx="17" cy="11" r="1" />
    </svg>
    """
  end

  def icon(%{name: :sparkle} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.75"
      class={@class}
      aria-hidden="true"
      {@rest}
    >
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 3v6M12 15v6M3 12h6M15 12h6M5 5l4 4M15 15l4 4M5 19l4-4M15 9l4-4" />
    </svg>
    """
  end

  def icon(%{name: :flower} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.75"
      class={@class}
      aria-hidden="true"
      {@rest}
    >
      <circle cx="12" cy="8" r="2.5" />
      <circle cx="8" cy="12" r="2.5" />
      <circle cx="16" cy="12" r="2.5" />
      <circle cx="12" cy="16" r="2.5" />
      <path stroke-linecap="round" d="M12 18.5V22" />
    </svg>
    """
  end
end
