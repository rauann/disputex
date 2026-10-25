defmodule DisputexWeb.PageController do
  use DisputexWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
