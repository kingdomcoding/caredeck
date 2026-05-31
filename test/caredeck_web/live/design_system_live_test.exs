defmodule CaredeckWeb.DesignSystemLiveTest do
  use CaredeckWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the design system page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/design-system")

    assert html =~ "Caredeck Design System"
    assert html =~ "Brand teal"
    assert html =~ "Formfix status badges"
    assert html =~ "Typography"
    assert html =~ "Cards"
    assert html =~ "Like"
    assert html =~ "bg-teal-500"
    assert html =~ "bg-status-draft-bg"
    assert html =~ "rounded-card"
    assert html =~ "shadow-fab"
    assert html =~ "Approved"
  end
end
