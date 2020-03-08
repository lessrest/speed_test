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

  @spec close(pid) :: true
  def close(page) do
    Process.exit(page, :normal)
  end

  @spec dimensions(pid, %{width: number(), height: number()}, nil | options()) ::
          {:ok, any()} | {:error, any()}
  def dimensions(server, params, options \\ []) do
    GenServer.call(server, {:dimensions, params, options}, options[:timeout] || @timeout)
  end

  @spec goto(pid, binary(), options()) :: :ok | {:error, :timeout} | {:error, any()}
  def goto(server, url, options \\ []) do
    GenServer.call(server, {:visit, url, options}, options[:timeout] || @timeout)
  end

  @spec pdf(pid, %{path: binary()} | %{}, options) :: :ok | {:error, any()}
  def pdf(server, params \\ %{}, options \\ []) do
    GenServer.call(server, {:pdf, params, options}, options[:timeout] || @timeout)
  end

  @spec screenshot(pid, %{path: binary()} | %{}, options) :: :ok | {:error, any()}
  def screenshot(server, params \\ %{}, options \\ []) do
    GenServer.call(server, {:screenshot, params, options}, options[:timeout] || @timeout)
  end

  @spec get(pid, node_id(), options()) :: {:ok, node_id} | {:error, :timeout} | {:error, any()}
  def get(server, selector, options \\ []) do
    GenServer.call(
      server,
      {:get, %{selector: selector, retry: options[:retry] || %Retry{}},
       Keyword.delete(options, :retry)},
      options[:timeout] || @timeout
    )
  end

  @spec focus(pid, node_id(), options()) :: :ok | {:error, any()}
  def focus(server, node_id, options \\ []) do
    GenServer.call(
      server,
      {:focus, %{node_id: node_id}, options},
      options[:timeout] || @timeout
    )
  end

  @spec type(pid, node_id(), binary(), options()) :: :ok | {:error, any()}
  def type(server, node_id, text, options \\ []) do
    GenServer.call(
      server,
      {:type, %{node_id: node_id, text: text}, options},
      options[:timeout] || @timeout
    )
  end

  @spec value(pid, node_id(), options()) :: binary() | :notfound
  def value(server, node_id, options \\ []) do
    GenServer.call(
      server,
      {:property, %{node_id: node_id, property: "value"}, options},
      options[:timeout] || @timeout
    )
  end

  @spec property(pid, node_id(), binary(), options) :: binary() | :notfound
  def property(server, node_id, property, options \\ []) do
    GenServer.call(
      server,
      {:property, %{node_id: node_id, property: property}, options},
      options[:timeout] || @timeout
    )
  end

  @spec text(pid, node_id(), options()) :: binary() | :notfound
  def text(server, node_id, options \\ []) do
    GenServer.call(
      server,
      {:property, %{node_id: node_id, property: "textContent"}, options},
      options[:timeout] || @timeout
    )
  end

  @spec attributes(pid, node_id(), options()) :: {:ok, map()} | :notfound
  def attributes(server, node_id, options \\ []) do
    GenServer.call(
      server,
      {:attribute, %{node_id: node_id}, options},
      options[:timeout] || @timeout
    )
  end

  @spec attribute(pid, node_id(), binary(), options()) :: {:ok, binary()} | :notfound
  def attribute(server, node_id, attribute, options \\ []) do
    GenServer.call(
      server,
      {:attribute, %{node_id: node_id, attribute: attribute}, options},
      options[:timeout] || @timeout
    )
  end

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

  @spec wait_for_load(pid, options()) :: :ok | {:error, :timeout}
  def wait_for_load(server, options \\ []) do
    GenServer.call(
      server,
      {:wait_for_load, %{}, options},
      options[:timeout] || @timeout
    )
  end

  @spec wait_for_url(pid(), binary(), options()) ::
          {:ok, any()} | {:error, :timeout} | {:error, any()}
  def wait_for_url(server, url, options \\ []) do
    GenServer.call(
      server,
      {:wait_for_url, %{url: url, retry: options[:retry] || %Retry{}}},
      options[:timeout] || @timeout
    )
  end

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
             httpOnly: cookie.httpOnly,
             sameSite: cookie.sameSite,
             expires: cookie.expires
           }
         ]
       }, options},
      options[:timeout] || @timeout
    )
  end

  @spec current_url(pid(), options()) :: binary()
  def current_url(server, options \\ []) do
    GenServer.call(
      server,
      {:url},
      options[:timeout] || @timeout
    )
  end

  @spec intercept_request(
          pid,
          binary,
          binary,
          options()
        ) :: :ok | {:error, :timeout}
  def intercept_request(server, method, url, options \\ []) do
    GenServer.call(
      server,
      {:network, %{url: url, method: String.upcase(method), retry: options[:retry] || %Retry{}}},
      options[:timeout] || @timeout
    )
  end

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
