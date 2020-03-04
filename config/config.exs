import Config

config :chroxy,
  chrome_remote_debug_port_from: System.get_env("CHROXY_CHROME_PORT_FROM") || "9222",
  chrome_remote_debug_port_to: System.get_env("CHROXY_CHROME_PORT_TO") || "9223"

config :chroxy, Chroxy.ProxyListener,
  host: System.get_env("CHROXY_PROXY_HOST") || "127.0.0.1",
  port: System.get_env("CHROXY_PROXY_PORT") || "1331"

config :chroxy, Chroxy.ProxyServer, packet_trace: false

config :chroxy, Chroxy.Endpoint,
  scheme: :http,
  port: System.get_env("CHROXY_ENDPOINT_PORT") || "1330"

config :chroxy, Chroxy.ChromeServer,
  page_wait_ms: System.get_env("CHROXY_CHROME_SERVER_PAGE_WAIT_MS") || "200",
  crash_dumps_dir: System.get_env("CHROME_CHROME_SERVER_CRASH_DUMPS_DIR") || "/tmp",
  verbose_logging: 0

import_config "#{Mix.env()}.exs"
