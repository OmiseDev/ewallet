use Mix.Config

config :ewallet_db, EWalletDB.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: {:system, "DATABASE_URL", "postgres://localhost/ewallet_dev"}

config :cloak, Salty.SecretBox.Cloak,
  tag: "SBX",
  default: true,
  keys: [
    %{
      tag: <<1>>,
      key: "j6fy7rZP9ASvf1bmywWGRjrmh8gKANrg40yWZ-rSKpI",
      default: true
    }
  ]
