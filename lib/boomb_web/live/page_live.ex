# lib/boomb_web/live/page_live.ex
defmodule BoombWeb.PageLive do
  use BoombWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:live_view, true)
      |> assign(:current_user, session["current_user"] || nil)
      |> assign(:current_path, session["current_path"] || "/")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
    <.live_component
      module={BoombWeb.ModalComponent}
      id="auth-modal"
      return_to={@current_path}
    />
      <h1>Welcome to Boomb!</h1>
      <%= if @current_user do %>
        <p>You are logged in as <%= @current_user.email %>.</p>
      <% else %>
        <p>Please log in or register to continue.</p>
      <% end %>
    </div>
    """
  end
end