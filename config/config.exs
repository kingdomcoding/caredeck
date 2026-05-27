import Config

config :caredeck,
  ecto_repos: [Caredeck.Repo],
  ash_domains: [Caredeck.Accounts],
  generators: [timestamp_type: :utc_datetime]

config :caredeck, CaredeckWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: CaredeckWeb.ErrorHTML, json: CaredeckWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Caredeck.PubSub,
  live_view: [signing_salt: "CQdxNq/0"]

config :esbuild,
  version: "0.25.4",
  caredeck: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

config :tailwind,
  version: "4.0.9",
  caredeck: [
    args: ~w(
      --input=css/app.css
      --output=../priv/static/assets/css/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :ash, :include_embedded_source_by_default?, false
config :ash, :default_page_type, :keyset
config :spark, formatter: [remove_parens?: true]

config :swoosh, :api_client, Swoosh.ApiClient.Req

config :caredeck, Caredeck.Mailer, adapter: Swoosh.Adapters.Local
config :caredeck, :from_email, {"Caredeck", "no-reply@caredeck.josboxoffice.com"}

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
