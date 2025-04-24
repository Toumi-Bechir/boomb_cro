# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :boomb,
  ecto_repos: [Boomb.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :boomb, BoombWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BoombWeb.ErrorHTML, json: BoombWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Boomb.PubSub,
  live_view: [signing_salt: "BmjvYatJ"]

  config :mnesia,
  dir: 'priv/mnesia'

  config :boomb,
    goalserve_api_key: "d306a694785d45065cb608dada5f9a88"

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
#config :boomb, Boomb.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh configuration
config :swoosh, :api_client, false

# Mailer configuration
config :boomb, Boomb.Mailer,
  adapter: Swoosh.Adapters.Local # For dev;

config :geoip,
  provider: :ip2locationio,
  api_key: "F663B9A13187BA93AABEFD3002235D9A"

config :boomb, :rate_limiting,
  max_failed_attempts: 3, # Maximum failed login attempts before locking
  lock_duration_minutes: 1 # Duration in minutes for the account lock

  
# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  boomb: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  boomb: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
