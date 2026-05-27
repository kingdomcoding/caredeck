defmodule CaredeckWeb.AuthFlowTest do
  use CaredeckWeb.ConnCase, async: true

  test "GET /sign-in renders the branded form", %{conn: conn} do
    conn = get(conn, ~p"/sign-in")
    body = html_response(conn, 200)
    assert body =~ "Sign in" or body =~ "sign-in" or body =~ "Sign In"
  end

  test "GET /register renders", %{conn: conn} do
    conn = get(conn, ~p"/register")
    assert html_response(conn, 200)
  end

  test "GET /password-reset-request renders", %{conn: conn} do
    conn = get(conn, ~p"/password-reset-request")
    assert html_response(conn, 200)
  end

  test "GET /team/sign-in renders", %{conn: conn} do
    conn = get(conn, ~p"/team/sign-in")
    assert html_response(conn, 200)
  end

  test "GET /healthz returns ok", %{conn: conn} do
    conn = get(conn, ~p"/healthz")
    assert text_response(conn, 200) == "ok"
  end
end
