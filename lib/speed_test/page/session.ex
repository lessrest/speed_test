defmodule SpeedTest.Page.Session do
  @moduledoc ~S"""
  Manages individual browser pages
  """
  use GenServer

  require Logger

  alias ChromeRemoteInterface.{HTTP, PageSession, RPC, Server}
  alias SpeedTest.Page.Registry

  @chrome_server %Server{host: "localhost", port: 1330}
  @timeout :timer.seconds(30)

  # Client functions

  # Server functions

  @impl true
  def init(%{page: page} = state) do
    # Register the process globally
    {:ok, _registry} = Registry.register(page)

    server = state[:server] || @chrome_server
    pid = launch(server)
    {:ok, _data} = RPC.Page.enable(pid)
    {:ok, _data} = RPC.Runtime.enable(pid)
    {:ok, _data} = RPC.Log.enable(pid)
    {:ok, _data} = RPC.Network.enable(pid)
    {:ok, _data} = RPC.Performance.enable(pid)
    {:ok, _data} = RPC.Profiler.enable(pid)
    {:ok, _data} = RPC.Security.enable(pid)

    state = state |> Map.put(:pid, pid) |> Map.put(:page, page)

    {:ok, state}
  end

  @impl true
  def handle_call({:visit, url, options}, _from, %{pid: pid} = state) do
    load_event = "Page.loadEventFired"

    with :ok <- PageSession.subscribe(pid, load_event),
         {:ok, _data} <- RPC.Page.navigate(pid, %{url: url}, options) do
      receive do
        {:chrome_remote_interface, ^load_event, _result} ->
          :ok = PageSession.unsubscribe(pid, load_event)
          {:reply, :ok, state}
      after
        @timeout ->
          {:reply, {:error, :timeout}, state}
      end
    end
  end

  @doc ~S"""
  const {
      scale = 1,
      displayHeaderFooter = false,
      headerTemplate = '',
      footerTemplate = '',
      printBackground = false,
      landscape = false,
      pageRanges = '',
      preferCSSPageSize = false,
      margin = {},
      path = null
    } = options;
  """
  @impl true
  def handle_call({:pdf, %{path: path} = params, options}, _from, %{pid: pid} = state)
      when not is_nil(path) do
    with {:ok, %{"id" => _id, "result" => %{"data" => data}}} <-
           RPC.Page.printToPDF(pid, params, options),
         {:ok, data} <- Base.decode64(data),
         :ok <- File.write(Path.expand(path), data) do
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:pdf, params, options}, _from, %{pid: pid} = state) do
    with {:ok, %{"id" => _id, "result" => %{"data" => data}}} <-
           RPC.Page.printToPDF(pid, params, options),
         {:ok, decoded} <- Base.decode64(data) do
      {:reply, decoded, state}
    end
  end

  @impl true
  def handle_call({:screenshot, %{path: path} = params, options}, _from, %{pid: pid} = state)
      when not is_nil(path) do
    with {:ok, %{"id" => _id, "result" => %{"data" => data}}} <-
           RPC.Page.captureScreenshot(pid, params, options),
         {:ok, data} <- Base.decode64(data),
         :ok <- File.write(Path.expand(path), data) do
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:screenshot, params, options}, _from, %{pid: pid} = state) do
    with {:ok, %{"id" => _id, "result" => %{"data" => data}}} <-
           RPC.Page.captureScreenshot(pid, params, options),
         {:ok, decoded} <- Base.decode64(data) do
      {:reply, decoded, state}
    end
  end

  @doc ~S"""
  width integer Overriding width value in pixels (minimum 0, maximum 10000000). 0 disables the override.
  height integer Overriding height value in pixels (minimum 0, maximum 10000000). 0 disables the override.
  deviceScaleFactor number Overriding device scale factor value. 0 disables the override.
  mobile boolean Whether to emulate mobile device. This includes viewport meta tag, overlay scrollbars, text autosizing and more.
  screenOrientation ScreenOrientation Screen orientation override.
  """
  @impl true
  def handle_call(
        {:dimensions, %{width: _width, height: _height} = params, options},
        _from,
        %{pid: pid} = state
      ) do
    resize_event = "Page.frameResized"

    default_params = %{
      width: 0,
      height: 0,
      deviceScaleFactor: 0,
      mobile: false
    }

    with :ok <- PageSession.subscribe(pid, resize_event),
         {:ok, _res} <-
           RPC.Emulation.setDeviceMetricsOverride(pid, Map.merge(default_params, params), options) do
      receive do
        {:chrome_remote_interface, ^resize_event, _result} ->
          :ok = PageSession.unsubscribe(pid, resize_event)
          {:reply, :ok, state}
      after
        @timeout ->
          {:reply, {:error, :timeout}, state}
      end
    end
  end

  @impl true
  def handle_call({:get, %{selector: selector} = params, options}, _from, %{pid: pid} = state) do
    with {:ok, %{"result" => %{"root" => %{"nodeId" => root_node}}}} <-
           RPC.DOM.getDocument(pid, params, options),
         {:ok, %{"result" => %{"nodeId" => id}}} <-
           RPC.DOM.querySelector(pid, %{"nodeId" => root_node, "selector" => selector}, options) do
      case id do
        0 ->
          {:reply, {:error, :notfound}, state}

        id ->
          {:reply, {:ok, id}, state}
      end
    end
  end

  @impl true
  def handle_call(
        {:focus, %{node_id: node_id}, options},
        _from,
        %{pid: pid} = state
      ) do
    with {:ok, _result} <-
           RPC.DOM.focus(pid, %{"nodeId" => node_id}, options) do
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(
        {:type, %{node_id: node_id, text: text}, options},
        _from,
        %{pid: pid} = state
      ) do
    with {:ok, _result} <-
           RPC.DOM.focus(pid, %{"nodeId" => node_id}, options),
         characters <- text |> String.graphemes(),
         results <-
           characters
           |> Enum.map(fn char ->
             RPC.Input.dispatchKeyEvent(pid, %{
               "text" => char,
               "unmodifiedText" => char,
               "key" => char,
               "type" => "keyDown"
             })
           end),
         true <- Enum.all?(results, fn {result, _} -> result == :ok end) do
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(
        {:property, %{property: property, node_id: node_id}, options},
        _from,
        %{pid: pid} = state
      ) do
    with {:ok, %{"result" => %{"object" => %{"objectId" => object_id}}}} <-
           RPC.DOM.resolveNode(pid, %{"nodeId" => node_id}),
         {:ok, %{"result" => %{"result" => properties}}} <-
           RPC.Runtime.getProperties(
             pid,
             %{
               "objectId" => object_id
             },
             options
           ),
         %{"value" => %{"value" => value}} <-
           Enum.find(properties, &(&1["name"] == property)) do
      {:reply, value, state}
    else
      nil ->
        {:reply, :notfound, state}
    end
  end

  @impl true
  def handle_call(
        {:attribute, %{node_id: node_id} = params, options},
        _from,
        %{pid: pid} = state
      ) do
    with {:ok, %{"result" => %{"attributes" => attributes}}} <-
           RPC.DOM.getAttributes(
             pid,
             %{
               "nodeId" => node_id
             },
             options
           ),
         attributes <-
           attributes
           |> Enum.chunk_every(2)
           |> Enum.into(%{}, fn [a, b] -> {a, b} end),
         value <-
           if(params[:attribute], do: attributes[params[:attribute]], else: attributes) do
      {:reply, {:ok, value}, state}
    else
      nil ->
        {:reply, :notfound, state}
    end
  end

  @impl true
  def handle_call(
        {:click, %{node_id: node_id}, options},
        _from,
        %{pid: pid} = state
      ) do
    with {:ok, %{"result" => %{"model" => %{"content" => [x, y | _rest]}}}} <-
           RPC.DOM.getBoxModel(pid, %{"nodeId" => node_id}, options),
         {:ok, _result} <-
           RPC.Input.dispatchMouseEvent(pid, %{
             "type" => "mousePressed",
             "button" => "left",
             "clickCount" => 1,
             "x" => x,
             "y" => y
           }),
         {:ok, _result} <-
           RPC.Input.dispatchMouseEvent(pid, %{
             "type" => "mouseReleased",
             "button" => "left",
             "clickCount" => 1,
             "x" => x,
             "y" => y
           }) do
      {:reply, :ok, state}
    else
      nil ->
        {:reply, :notfound, state}
    end
  end

  @impl true
  def handle_call({:wait_for_load, %{}, options}, _from, %{pid: pid} = state) do
    load_event = "Page.loadEventFired"

    with :ok <- PageSession.subscribe(pid, load_event, options) do
      receive do
        {:chrome_remote_interface, ^load_event, _result} ->
          :ok = PageSession.unsubscribe(pid, load_event)
          {:reply, :ok, state}
      after
        @timeout ->
          {:reply, {:error, :timeout}, state}
      end
    end
  end

  @spec start_link(any, %{page: any}) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_, %{page: page}) do
    # Register the PID for this session
    GenServer.start_link(__MODULE__, %{
      page: page,
      pid: nil
    })
  end

  defp session!(server) do
    {:ok, ws} = HTTP.call(server, "/api/v1/connection")
    Logger.debug("WebSocket: #{ws}")
    ws
  end

  defp launch(server) do
    server
    |> session!()
    |> PageSession.start_link()
    |> elem(1)
  end
end
