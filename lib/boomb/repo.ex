defmodule Boomb.Repo do
  use Ecto.Repo,
    otp_app: :boomb,
    adapter: Ecto.Adapters.MyXQL
end
