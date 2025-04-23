defmodule BoombWeb.ErrorHelpers do
  use Phoenix.Component

  def error_tag(assigns) do
    assigns = assign_new(assigns, :class, fn -> "text-red-500 text-sm" end)

    ~H"""
    <%= for error <- Keyword.get_values(@form.errors, @field) do %>
      <span class={@class}><%= translate_error(error) %></span>
    <% end %>
    """
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end