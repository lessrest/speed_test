defmodule SpeedTest do
  @moduledoc """
  Documentation for SpeedTest.
  """

  require Logger

  @timeout :timer.seconds(30)

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

  def type(server, node_id, text, options \\ []) do
    GenServer.call(
      server,
      {:type, %{node_id: node_id, text: text}, options},
      options[:timeout] || @timeout
    )
  end

  def get_attribute(server, node_id, attribute, options \\ []) do
    GenServer.call(
      server,
      {:evaluate, %{node_id: node_id, attribute: attribute}, options},
      options[:timeout] || @timeout
    )
  end
end
