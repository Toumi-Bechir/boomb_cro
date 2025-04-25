defmodule Boomb.UserLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_logs" do
    belongs_to :user, Boomb.Accounts.User
    field :action, :string
    field :status, :string
    field :ip_address, :string
    field :local_time, :string
    field :timezone, :string
    field :city, :string
    field :region, :string
    field :country, :string
    field :latitude, :float
    field :longitude, :float
    field :user_agent, :string
    field :device, :string
    field :device_type, :string
    field :os, :string
    field :browser, :string
    field :browser_version, :string
    field :session_token, :string # Ensure this field is present
    field :error_message, :string

    timestamps()
  end

  def changeset(user_log, attrs) do
    user_log
    |> cast(attrs, [
      :user_id,
      :action,
      :status,
      :ip_address,
      :local_time,
      :timezone,
      :city,
      :region,
      :country,
      :latitude,
      :longitude,
      :user_agent,
      :device,
      :device_type,
      :os,
      :browser,
      :browser_version,
      :session_token,
      :error_message
    ])
    |> validate_required([:action, :status])
  end
end