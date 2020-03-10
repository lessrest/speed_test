defmodule SpeedTest do
  @moduledoc """
  High level wrapper for the chrome debug protocol and managing
  headless chrome browsers.
  """

  require Logger

  @timeout :timer.seconds(30)

  alias SpeedTest.{Cookie, Retry}
  alias SpeedTest.Page.{Registry, Session, Supervisor}

  @type options() :: [timeout: timeout(), retry: SpeedTest.Retry.t()]
  @type node_id :: integer()

  @spec launch(atom | %{id: any}) :: pid
  @doc ~S"""
  Launch creates a new browser session inside headless chrome.

  ### Examples

      iex> page = SpeedTest.launch()
      iex> is_pid(page)
      true

  """
  def launch(page \\ %{id: UUID.uuid4()}) do
    case Registry.lookup(page) do
      {:ok, {pid, _page_data}} ->
        pid

      _ ->
        {:ok, pid} = Supervisor.start_child(Session, %{page: page, server: nil})

        pid
    end
  end

  @doc ~S"""
  Closes a page process.
  *Note* this does NOT stop the underlying chroxy chrome process

  ### Examples

      iex> page = SpeedTest.launch()
      iex> SpeedTest.close(page)
      true

  """
  @spec close(pid) :: true
  def close(page) do
    Process.exit(page, :normal)
  end

  @doc ~S"""
  Changes the dimensions of a given page

  ### Examples

    iex> page = SpeedTest.launch()
    iex> page |> SpeedTest.dimensions(%{width: 1920, height: 1080})
    :ok
  """
  @spec dimensions(pid, %{width: number(), height: number()}, nil | options()) ::
          :ok | {:error, any()}
  def dimensions(server, params, options \\ []) do
    GenServer.call(server, {:dimensions, params, options}, options[:timeout] || @timeout)
  end

  @doc ~S"""
  Navigates to a given URL. This URL can be shorted by providing the configuration value :base_url

  i.e. `config :speed_test, base_url: "http://localhost:4003"`

  ### Examples

      iex> page = SpeedTest.launch()
      iex> page |> SpeedTest.goto("/")
      :ok

  """
  @spec goto(pid, binary(), options()) :: :ok | {:error, :timeout} | {:error, any()}
  def goto(server, url, options \\ []) do
    GenServer.call(server, {:visit, url, options}, options[:timeout] || @timeout)
  end

  @doc ~S"""
  Creates a PDF from the current page. Optionally can be saved to a provided path.

  # Parameters

  * scale = 1,
  * displayHeaderFooter = false,
  * headerTemplate = '',
  * footerTemplate = '',
  * printBackground = false,
  * landscape = false,
  * pageRanges = '',
  * preferCSSPageSize = false,
  * margin = {},
  * path = null

  ### Examples

      iex> page = SpeedTest.launch()
      iex> page |> SpeedTest.goto("/")
      iex> {:ok, pdf} = page |> SpeedTest.pdf("/")
      iex> is_binary(pdf) and String.length(pdf) > 0
      true
  """
  @spec pdf(pid, %{path: binary()} | %{}, options) :: :ok | {:ok, binary()} | {:error, any()}
  def pdf(server, params \\ %{}, options \\ []) do
    GenServer.call(server, {:pdf, params, options}, options[:timeout] || @timeout)
  end

  @doc ~S"""
  Captures a screenshot of the current window. Optionally saves the output to a given path

  ### Examples

      iex> page = SpeedTest.launch()
      iex> page |> SpeedTest.goto("/")
      iex> {:ok, png} = page |> SpeedTest.screenshot("/")
      iex> is_binary(png) and String.length(png) > 0
      true
  """
  @spec screenshot(pid, %{path: binary()} | %{}, options) ::
          :ok | {:ok, binary()} | {:error, any()}
  def screenshot(server, params \\ %{}, options \\ []) do
    GenServer.call(server, {:screenshot, params, options}, options[:timeout] || @timeout)
  end

  @doc ~S"""
  Gets a `t:node_id/0` to a given selector on the page.

  ### Examples

      iex> page = SpeedTest.launch()
      iex> :ok = page |> SpeedTest.goto("/")
      iex> {:ok, id} = page |> SpeedTest.get("input")
      iex> is_integer(id)
      true
      iex> {:ok, id} = page |> SpeedTest.get("[data-test=login_email]")
      iex> is_integer(id)
      true

  """
  @spec get(pid, node_id(), options()) :: {:ok, node_id} | {:error, :timeout} | {:error, any()}
  def get(server, selector, options \\ []) do
    GenServer.call(
      server,
      {:get, %{selector: selector, retry: options[:retry] || %Retry{}},
       Keyword.delete(options, :retry)},
      options[:timeout] || @timeout
    )
  end

  @doc ~S"""
  Focuses on a given node.

  ### Examples

      iex> page = SpeedTest.launch()
      iex> :ok = page |> SpeedTest.goto("/")
      iex> {:ok, id} = page |> SpeedTest.get("input")
      iex> page |> SpeedTest.focus(id)
      :ok
  """
  @spec focus(pid, node_id(), options()) :: :ok | {:error, any()}
  def focus(server, node_id, options \\ []) do
    GenServer.call(
      server,
      {:focus, %{node_id: node_id}, options},
      options[:timeout] || @timeout
    )
  end

  @doc ~S"""
  Types text in a given node.

  ### Examples

      iex> page = SpeedTest.launch()
      iex> :ok = page |> SpeedTest.goto("/")
      iex> {:ok, email_input} = page |> SpeedTest.get("[data-test=login_email]")
      iex> :ok = page |> SpeedTest.type(email_input, "testing@test.com")
      iex> page |> SpeedTest.value(email_input)
      {:ok, "testing@test.com"}
  """
  @spec type(pid, node_id(), binary(), options()) :: :ok | {:error, any()}
  def type(server, node_id, text, options \\ []) do
    GenServer.call(
      server,
      {:type, %{node_id: node_id, text: text}, options},
      options[:timeout] || @timeout
    )
  end

  @doc ~S"""
  Gets the "value" property from a given node.

  ### Examples

      iex> page = SpeedTest.launch()
      iex> :ok = page |> SpeedTest.goto("/")
      iex> {:ok, email_input} = page |> SpeedTest.get("[data-test=login_email]")
      iex> page |> SpeedTest.value(email_input)
      {:ok, ""}
  """
  @spec value(pid, node_id(), options()) :: binary() | :notfound
  def value(server, node_id, options \\ []) do
    GenServer.call(
      server,
      {:property, %{node_id: node_id, property: "value"}, options},
      options[:timeout] || @timeout
    )
  end

  @doc ~S"""
  Gets arbitrary properties from a dom node.

  ### Examples

      iex> page = SpeedTest.launch()
      iex> :ok = page |> SpeedTest.goto("/")
      iex> {:ok, email_input} = page |> SpeedTest.get("[data-test=login_email]")
      iex> page |> SpeedTest.property(email_input, "type")
      {:ok, "email"}
  """
  @spec property(pid, node_id(), binary(), options) :: {:ok, binary()} | {:error, :notfound}
  def property(server, node_id, property, options \\ []) do
    GenServer.call(
      server,
      {:property, %{node_id: node_id, property: property}, options},
      options[:timeout] || @timeout
    )
  end

  @doc ~S"""
  Utility function for returning the text of a DOM node ("textContent" property)

  ### Examples

      iex> page = SpeedTest.launch()
      iex> :ok = page |> SpeedTest.goto("/")
      iex> {:ok, header} = page |> SpeedTest.get("h1")
      iex> page |> SpeedTest.text(header)
      {:ok, "I am a website"}
  """
  @spec text(pid, node_id(), options()) :: {:ok, binary()} | {:error, :notfound}
  def text(server, node_id, options \\ []) do
    GenServer.call(
      server,
      {:property, %{node_id: node_id, property: "textContent"}, options},
      options[:timeout] || @timeout
    )
  end

  @doc ~S"""
  Returns all attributes for a dom node as a map

  ### Examples

      iex> page = SpeedTest.launch()
      iex> :ok = page |> SpeedTest.goto("/")
      iex> {:ok, input} = page |> SpeedTest.get("input")
      iex> page |> SpeedTest.attributes(input)
      {:ok, %{"type" => "email", "data-test" => "login_email", "name" => "test"}}
  """
  @spec attributes(pid, node_id(), options()) :: {:ok, map()} | :notfound
  def attributes(server, node_id, options \\ []) do
    GenServer.call(
      server,
      {:attribute, %{node_id: node_id}, options},
      options[:timeout] || @timeout
    )
  end

  @doc ~S"""
  Returns a single attribute for a node

  ### Examples

      iex> page = SpeedTest.launch()
      iex> :ok = page |> SpeedTest.goto("/")
      iex> {:ok, input} = page |> SpeedTest.get("input")
      iex> page |> SpeedTest.attribute(input, "name")
      {:ok, "test"}
  """
  @spec attribute(pid, node_id(), binary(), options()) :: {:ok, binary()} | :notfound
  def attribute(server, node_id, attribute, options \\ []) do
    GenServer.call(
      server,
      {:attribute, %{node_id: node_id, attribute: attribute}, options},
      options[:timeout] || @timeout
    )
  end

  @doc ~S"""
  Clicks on a dom node. Can take in a params object with the number of times to click.

  ### Examples

      iex> page = SpeedTest.launch()
      iex> :ok = page |> SpeedTest.goto("/")
      iex> {:ok, button} = page |> SpeedTest.get("button")
      iex> page |> SpeedTest.click(button)
      :ok
      iex> page |> SpeedTest.click(button, %{click_count: 2})
      :ok
  """
  @spec click(pid, node_id(), %{click_count: integer()} | %{}, options()) :: :ok | {:error, any()}
  def click(server, node_id, params \\ %{}, options \\ [])

  def click(server, node_id, %{click_count: count}, options) do
    GenServer.call(
      server,
      {:click, %{node_id: node_id, click_count: count}, options},
      options[:timeout] || @timeout
    )
  end

  def click(server, node_id, _params, options) do
    GenServer.call(
      server,
      {:click, %{node_id: node_id}, options},
      options[:timeout] || @timeout
    )
  end

  @doc ~S"""
  Waits for the current URL to equal the provided one. Useful if you have a redirect that
  occurs after some user action.

  ### Examples

      iex> page = SpeedTest.launch()
      iex> :ok = page |> SpeedTest.goto("/")
      iex> :ok = page |> SpeedTest.wait_for_url("/", retry: %SpeedTest.Retry{timeout: :timer.seconds(2)})
      :ok
  """
  @spec wait_for_url(pid(), binary(), options()) ::
          {:ok, any()} | {:error, :timeout} | {:error, any()}
  def wait_for_url(server, url, options \\ []) do
    GenServer.call(
      server,
      {:wait_for_url, %{url: url, retry: options[:retry] || %Retry{}}},
      options[:timeout] || @timeout
    )
  end

  @doc ~S"""
  Sets a cookie on the page.

  ### Examples

      iex> page = SpeedTest.launch()
      iex> :ok = page |> SpeedTest.goto("/")
      iex> page |> SpeedTest.set_cookie(%SpeedTest.Cookie{domain: "localhost", name: "testing", value: "123"})
      :ok
  """
  @spec set_cookie(
          pid(),
          SpeedTest.Cookie.t(),
          options()
        ) :: :ok | any()
  def set_cookie(server, %Cookie{} = cookie, options \\ []) do
    GenServer.call(
      server,
      {:set_cookies,
       %{
         cookies: [
           %{
             name: cookie.name,
             value: cookie.value,
             url: cookie.url,
             domain: cookie.domain,
             path: cookie.path,
             secure: cookie.secure,
             httpOnly: cookie.http_only,
             sameSite: cookie.same_site,
             expires: cookie.expires
           }
         ]
       }, options},
      options[:timeout] || @timeout
    )
  end

  @doc ~S"""
  Gets a cookie from the page

  ### Examples

      iex> page = SpeedTest.launch()
      iex> :ok = page |> SpeedTest.goto("/")
      iex> page |> SpeedTest.set_cookie(%SpeedTest.Cookie{domain: "localhost", name: "testing", value: "123"})
      :ok
      iex> page |> SpeedTest.get_cookie("testing")
      %SpeedTest.Cookie{domain: "localhost", name: "testing", value: "123"}
  """
  @spec get_cookie(pid(), binary(), options()) ::
          {:ok, SpeedTest.Cookie.t()} | {:error, :notfound}
  def get_cookie(server, name, options \\ []) do
    GenServer.call(
      server,
      {:get_cookie, name, options},
      options[:timeout] || @timeout
    )
  end

  @doc ~S"""
  Returns the current URL

  ### Examples

      iex> page = SpeedTest.launch()
      iex> :ok = page |> SpeedTest.goto("/")
      iex> page |> SpeedTest.current_url()
      "http://localhost:8081/"
  """
  @spec current_url(pid(), options()) :: binary()
  def current_url(server, options \\ []) do
    GenServer.call(
      server,
      {:url},
      options[:timeout] || @timeout
    )
  end

  @doc ~S"""
  Waits for a given network request to happen. Can be anything that shows up in the network tab from XHR
  request to CSS to javascript.

  *NOTE* you do not want to use this on the home page since the goto() function already waits for page load
  and will not record that HTTP request.

  ### Examples

      iex> page = SpeedTest.launch()
      iex> :ok = page |> SpeedTest.goto("/")
      iex> {:ok, %{"request" => %{"url" => "http://localhost:8081/app.js"}, "response" => %{"status" => 200}}} = page |> SpeedTest.intercept_request("GET", "/app.js")
  """
  @spec intercept_request(
          pid,
          binary,
          binary,
          options()
        ) :: {:ok, map()} | {:error, :timeout}
  def intercept_request(server, method, url, options \\ []) do
    GenServer.call(
      server,
      {:network, %{url: url, method: String.upcase(method), retry: options[:retry] || %Retry{}}},
      options[:timeout] || @timeout
    )
  end

  @doc ~S"""
  Clears a text input. Wrapper fro calling click on an input 3 times and typing backspace.

  ### Examples

      iex> page = SpeedTest.launch()
      iex> :ok = page |> SpeedTest.goto("/")
      iex> {:ok, email_input} = page |> SpeedTest.get("[data-test=login_email]")
      iex> :ok = page |> SpeedTest.type(email_input, "testing@test.com")
      iex> page |> SpeedTest.value(email_input)
      {:ok, "testing@test.com"}
      iex> page |> SpeedTest.clear(email_input)
      :ok
      iex> page |> SpeedTest.value(email_input)
      {:ok, ""}
  """
  @spec clear(pid, node_id(), options()) :: :ok | {:error, :timeout}
  def clear(server, node, options \\ []) do
    with :ok <- server |> click(node, %{click_count: 3}, options),
         :ok <-
           server
           |> type(node, "\b", options) do
      :ok
    end
  end
end
