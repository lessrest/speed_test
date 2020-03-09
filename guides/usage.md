Usage
===============

## Installation
Add speed_test to your mix.exs

```elixir
def deps do
  [
    {:speed_test, "~> 0.1.0"}
  ]
end
```

Ensure that chrome is installed and available on the path.

#### Docker

If using docker you will need to install the necessary dependencies. The below config
runs speed tests with docker and alpine:

```docker
FROM alpine:edge

# Installs latest Chromium (77) package.
RUN apk add --no-cache \
      chromium \
      nss \
      freetype \
      freetype-dev \
      harfbuzz \
      ca-certificates \
      ttf-freefont

RUN addgroup -S spduser && adduser -S -g spduser spduser \
    && mkdir -p /home/spduser/Downloads /app \
    && chown -R spduser:spduser /home/spduser \
    && chown -R spduser:spduser /app

# Run everything after as non-privileged user.
USER spduser
```

Note: You will need to configure the chromium path to '/usr/bin/chromium-browser' in the chroxy settings

## Project Setup

When setting up a project the recommended way is to initialize a poncho app inside your main app (*NOT* umbrella).

To do this inside an application:

1. mix new e2e
1. Add parent app to mix.exs: `{:my_app, path: "../"},`
1. Add speed_test to mix.exs: `{:speed_test, "~> 0.1.0"}`
1. Import parent app config in config.exs `import_config "../../config/config.exs"`

Alternatively you could add speed_test as a dependency to your main application and configure it there along with tests.

## Configuration

#### Chroxy

First you'll need to configure chroxy, the thing that manages your chrome headless sessions.

```elixir
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
```

The only other configuration options in speed test is your base URL.

```elixir
config :speed_test, base_url: "http://localhost:4003"
```

## Writing Tests

In new tests I usually import speed test and then in the setup block load a new page and pass that into the test block i.e.

```elixir
defmodule MyAppTest do
  use ExUnit.Case, async: true
  import SpeedTest

  setup do
    page = launch()
    dimensions(page, %{width: 1920, height: 1080})

    [page: page]
  end
end
```

Then use that to test against:

```elixir
describe "Home page" do
  test "fills in login email", %{page: page} do
    goto(page, "/")

    {:ok, email_input} = page |> get("[data-test=login_email]")
    :ok = page |> type(email_input, "testing@test.com")

    assert "testing@test.com" == page |> value(email_input)
  end
end
```
