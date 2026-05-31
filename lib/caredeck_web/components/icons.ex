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
end
