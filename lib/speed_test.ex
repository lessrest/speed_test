defmodule SpeedTest do
  @moduledoc """
  Documentation for SpeedTest.
  """

  require Logger

  @timeout :timer.seconds(30)

  alias SpeedTest.Cookie
  alias SpeedTest.Page.{Registry, Session, Supervisor}

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

  def close(page) do
    Process.exit(page, :normal)
  end

  def dimensions(server, params, options \\ []) do
    GenServer.call(server, {:dimensions, params, options}, options[:timeout] || @timeout)
  end

  def goto(server, url, options \\ []) do
    GenServer.call(server, {:visit, url, options}, options[:timeout] || @timeout)
  end

  def pdf(server, params \\ %{}, options \\ []) do
    GenServer.call(server, {:pdf, params, options}, options[:timeout] || @timeout)
  end

  def screenshot(server, params \\ %{}, options \\ []) do
    GenServer.call(server, {:screenshot, params, options}, options[:timeout] || @timeout)
  end

  def get(server, selector, options \\ []) do
    GenServer.call(server, {:get, %{selector: selector}, options}, options[:timeout] || @timeout)
  end

  def focus(server, node_id, options \\ []) do
    GenServer.call(
      server,
      {:focus, %{node_id: node_id}, options},
      options[:timeout] || @timeout
    )
  end

  def type(server, node_id, text, options \\ []) do
    GenServer.call(
      server,
      {:type, %{node_id: node_id, text: text}, options},
      options[:timeout] || @timeout
    )
  end

  def value(server, node_id, options \\ []) do
    GenServer.call(
      server,
      {:property, %{node_id: node_id, property: "value"}, options},
      options[:timeout] || @timeout
    )
  end

  def property(server, node_id, property, options \\ []) do
    GenServer.call(
      server,
      {:property, %{node_id: node_id, property: property}, options},
      options[:timeout] || @timeout
    )
  end

  def attributes(server, node_id, options \\ []) do
    GenServer.call(
      server,
      {:attribute, %{node_id: node_id}, options},
      options[:timeout] || @timeout
    )
  end

  def attribute(server, node_id, attribute, options \\ []) do
    GenServer.call(
      server,
      {:attribute, %{node_id: node_id, attribute: attribute}, options},
      options[:timeout] || @timeout
    )
  end

  def click(server, node_id, options \\ []) do
    GenServer.call(
      server,
      {:click, %{node_id: node_id}, options},
      options[:timeout] || @timeout
    )
  end

  def wait_for_load(server, options \\ []) do
    GenServer.call(
      server,
      {:wait_for_load, %{}, options},
      options[:timeout] || @timeout
    )
  end

  def wait_for_url(server, url, options \\ []) do
    GenServer.call(
      server,
      {:wait_for_url, %{url: url}},
      options[:timeout] || @timeout
    )
  end

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

  def current_url(server, options \\ []) do
    GenServer.call(
      server,
      {:url},
      options[:timeout] || @timeout
    )
  end
end
