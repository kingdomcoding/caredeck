defmodule CaredeckWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  override AshAuthentication.Phoenix.Components.Banner do
    set(:image_url, "/images/brand/caredeck-mark.svg")
    set(:href_url, "/")
    set(:image_class, "h-12 w-12 mx-auto")
  end

  override AshAuthentication.Phoenix.Components.SignIn do
    set(:show_banner, true)
    set(:root_class, "min-h-screen bg-page flex items-center justify-center px-4")
  end

  override AshAuthentication.Phoenix.Components.Password do
    set(:show_banner, true)
    set(:hide_class, "hidden")
    set(:root_class, "w-full max-w-sm mx-auto")
  end

  override AshAuthentication.Phoenix.Components.Password.SignInForm do
    set(:slot_class, "space-y-4")
    set(:form_class, "space-y-4 mt-6")
    set(:label_class, "block text-sm font-medium text-ink-700 mb-1")

    set(
      :input_class,
      "w-full px-4 py-3 rounded-button border border-divider bg-card text-ink-900 placeholder-ink-300 focus:outline-none focus:ring-2 focus:ring-teal-300"
    )

    set(
      :submit_class,
      "w-full rounded-button bg-brand text-white py-3 font-medium hover:bg-teal-600 focus:outline-none focus:ring-2 focus:ring-teal-300 transition"
    )

    set(:reset_toggle_text, "Forgot your password?")
    set(:reset_toggle_class, "text-sm text-brand hover:text-teal-700")
  end

  override AshAuthentication.Phoenix.Components.Password.RegisterForm do
    set(:slot_class, "space-y-4")
    set(:form_class, "space-y-4 mt-6")
    set(:label_class, "block text-sm font-medium text-ink-700 mb-1")

    set(
      :input_class,
      "w-full px-4 py-3 rounded-button border border-divider bg-card text-ink-900 placeholder-ink-300 focus:outline-none focus:ring-2 focus:ring-teal-300"
    )

    set(
      :submit_class,
      "w-full rounded-button bg-brand text-white py-3 font-medium hover:bg-teal-600 focus:outline-none focus:ring-2 focus:ring-teal-300 transition"
    )
  end

  override AshAuthentication.Phoenix.Components.Password.ResetForm do
    set(:slot_class, "space-y-4")
    set(:form_class, "space-y-4 mt-6")
    set(:label_class, "block text-sm font-medium text-ink-700 mb-1")

    set(
      :input_class,
      "w-full px-4 py-3 rounded-button border border-divider bg-card text-ink-900 placeholder-ink-300 focus:outline-none focus:ring-2 focus:ring-teal-300"
    )

    set(
      :submit_class,
      "w-full rounded-button bg-brand text-white py-3 font-medium hover:bg-teal-600 focus:outline-none focus:ring-2 focus:ring-teal-300 transition"
    )
  end

  override AshAuthentication.Phoenix.Components.HorizontalRule do
    set(:hide_text, true)
    set(:root_class, "my-6 border-t border-divider")
  end

  override AshAuthentication.Phoenix.Components.Password.Input do
    set(
      :submit_class,
      "w-full rounded-button bg-brand text-white py-3 font-medium hover:bg-teal-600 focus:outline-none focus:ring-2 focus:ring-teal-300 transition"
    )
  end
end
