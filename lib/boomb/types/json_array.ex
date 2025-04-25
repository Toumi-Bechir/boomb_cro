defmodule Boomb.Types.JsonArray do
  @behaviour Ecto.Type

  def type, do: :json

  def cast(value) when is_list(value), do: {:ok, value}
  def cast(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, list} when is_list(list) -> {:ok, list}
      _ -> :error
    end
  end
  def cast(_), do: :error

  def load(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, list} when is_list(list) -> {:ok, list}
      _ -> :error
    end
  end
  def load(_), do: :error

  def dump(value) when is_list(value), do: Jason.encode(value)
  def dump(_), do: :error

  # Implement equal?/2 to compare two lists of strings
  def equal?(value1, value2) when is_list(value1) and is_list(value2) do
    value1 == value2
  end
  def equal?(_, _), do: false
end