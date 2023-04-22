defmodule DemoWeb.PageLive do
  @moduledoc """
    DemoWeb is a LiveView module
  """
  use DemoWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, number: 0)}
  end

  def render(assigns) do
    ~H"""
    <div class="w-full text-center">
      <strong>
        <%= @number %>
        Hello World or not?
      </strong>
      <.button class="bg-blue-600 hover:bg-blue-300" phx-click="add">Add</.button>
      <.test />
    </div>
    """
  end

  def test(assigns) do
    ~H"""
      This is a text or maybe not?
    """
  end

  def handle_event("add", _params, socket) do
    {:noreply, assign(socket, number: socket.assigns.number+1)}
  end
end
