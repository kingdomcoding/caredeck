defmodule CaredeckWeb.PageController do
  use CaredeckWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
