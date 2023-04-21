defmodule DemoWeb.PageLive do
  @moduledoc """
    DemoWeb is a LiveView module
  """
  use DemoWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
