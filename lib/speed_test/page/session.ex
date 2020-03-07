defmodule SpeedTest.Page.Session do
  @moduledoc ~S"""
  Manages individual browser pages
  """
  use GenServer

  require Logger

  alias ChromeRemoteInterface.{HTTP, PageSession, RPC, Server}
  alias SpeedTest.Retry
  alias SpeedTest.Page.Registry

  @chrome_server %Server{host: "localhost", port: 1330}
  @timeout :timer.seconds(30)
  @base_url Application.get_env(:speed_test, :base_url) || ""

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

    # Subscribe to page navigations
    PageSession.subscribe(pid, "Page.frameNavigated")
    # And general lifecycles
    PageSession.subscribe(pid, "Page.lifecycleEvent")
    # And Network events
    PageSession.subscribe(pid, "Network.requestWillBeSent")
    PageSession.subscribe(pid, "Network.responseReceived")

    state =
      state
      |> Map.put(:pid, pid)
      |> Map.put(:page, page)
      |> Map.put(:url, "")
      |> Map.put(:main_frame, "")
      |> Map.put(:network_requests, %{})

    {:ok, state}
  end

  @impl true
  def handle_call({:visit, url, options}, _from, %{pid: pid} = state) do
    load_event = "Page.loadEventFired"

    with :ok <- PageSession.subscribe(pid, load_event),
         {:ok, %{"result" => %{"frameId" => main_frame}}} <-
           RPC.Page.navigate(pid, %{url: "#{@base_url}#{url}"}, options) do
      receive do
        {:chrome_remote_interface, ^load_event, _result} ->
          :ok = PageSession.unsubscribe(pid, load_event)
          {:reply, :ok, %{state | main_frame: main_frame}}
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
  def handle_call({:get, %{retry: retry} = params, options}, from, state) do
    Process.send_after(
      self(),
      {:retry, Map.put(params, :from, from),
       fn %{selector: selector}, %{pid: pid} ->
         with {:ok, %{"result" => %{"root" => %{"nodeId" => root_node}}}} <-
                RPC.DOM.getDocument(pid, options),
              {:ok, %{"result" => %{"nodeId" => id}}} <-
                RPC.DOM.querySelector(
                  pid,
                  %{"nodeId" => root_node, "selector" => selector},
                  options
                ) do
           case id do
             0 ->
               {:error, :notfound}

             id ->
               {:ok, {:ok, id}}
           end
         end
       end},
      retry.interval
    )

    {:noreply, state}
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
             params =
               case grapheme_to_key(char) do
                 {:raw, code} ->
                   code

                 {:text, t} ->
                   %{
                     "text" => t
                   }
               end

             RPC.Input.dispatchKeyEvent(pid, Map.put(params, "type", "keyDown"))
             RPC.Input.dispatchKeyEvent(pid, Map.put(params, "type", "keyUp"))
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
        {:click, %{node_id: node_id} = params, options},
        _from,
        %{pid: pid} = state
      ) do
    with {:ok, %{"result" => %{"model" => %{"content" => [x, y | _rest]}}}} <-
           RPC.DOM.getBoxModel(pid, %{"nodeId" => node_id}, options),
         {:ok, _result} <-
           RPC.Input.dispatchMouseEvent(pid, %{
             "type" => "mousePressed",
             "button" => "left",
             "clickCount" => params[:click_count] || 1,
             "x" => x,
             "y" => y
           }),
         {:ok, _result} <-
           RPC.Input.dispatchMouseEvent(pid, %{
             "type" => "mouseReleased",
             "button" => "left",
             "clickCount" => params[:click_count] || 1,
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

  @doc ~S"""

  """
  @impl true
  def handle_call({:set_cookies, %{cookies: cookies}, options}, _from, %{pid: pid} = state) do
    with {:ok, _result} <-
           RPC.Network.setCookies(
             pid,
             %{
               "cookies" => cookies
             },
             options
           ) do
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:url}, _from, %{url: url} = state) do
    {:reply, url, state}
  end

  @impl true
  def handle_call(
        {:wait_for_url, %{retry: retry} = params},
        from,
        state
      ) do
    Process.send_after(
      self(),
      {:retry, Map.put(params, :from, from),
       fn params, state ->
         if "#{@base_url}#{params.url}" == state.url, do: {:ok, :ok}, else: {:error, false}
       end},
      retry.interval
    )

    {:noreply, state}
  end

  @impl true
  def handle_call(
        {:network, %{retry: retry} = params},
        from,
        state
      ) do
    Process.send_after(
      self(),
      {:retry, Map.put(params, :from, from),
       fn %{url: url, method: method}, %{network_requests: network_requests} ->
         found? =
           network_requests
           |> Map.values()
           |> Enum.find(fn %{"request" => request} ->
             request["method"] == method and
               String.contains?(request["url"], "#{@base_url}#{url}")
           end)

         case not is_nil(found?) do
           true -> {:ok, {:ok, found?}}
           _ -> {:error, :notfound}
         end
       end},
      retry.interval
    )

    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:chrome_remote_interface, "Network.responseReceived",
         %{
           "params" => %{
             "frameId" => frame_id,
             "requestId" => request_id,
             "response" => response
           }
         }},
        %{main_frame: main_frame} = state
      )
      when main_frame == frame_id do
    {:noreply, put_in(state, [:network_requests, request_id, "response"], response)}
  end

  def handle_info({:chrome_remote_interface, "Network.responseReceived", _params}, state),
    do: {:noreply, state}

  @impl true
  def handle_info(
        {:chrome_remote_interface, "Network.requestWillBeSent",
         %{
           "params" => %{
             "frameId" => frame_id,
             "requestId" => request_id,
             "request" => request,
             "type" => type
           }
         }},
        %{main_frame: main_frame, network_requests: network_requests} = state
      )
      when frame_id == main_frame do
    {:noreply,
     %{
       state
       | network_requests:
           Map.put(network_requests, request_id, %{
             "response" => %{},
             "request" => request,
             "type" => type
           })
     }}
  end

  def handle_info({:chrome_remote_interface, "Network.requestWillBeSent", _params}, state),
    do: {:noreply, state}

  @impl true
  def handle_info(
        {:chrome_remote_interface, "Page.frameNavigated",
         %{"params" => %{"frame" => %{"id" => id, "url" => url}}}},
        %{main_frame: main_frame} = state
      )
      when main_frame == id do
    {:noreply, %{state | url: url, network_requests: %{}}}
  end

  def handle_info({:chrome_remote_interface, "Page.frameNavigated", _}, state),
    do: {:noreply, state}

  @impl true
  def handle_info(
        {:retry,
         %{
           from: from,
           retry: %{attempts: attempts} = retry
         } = params, function},
        state
      ) do
    max = Retry.calc_max(retry)

    case function.(params, state) do
      {:ok, result} ->
        GenServer.reply(from, result)

      _anything when attempts >= max ->
        GenServer.reply(from, {:error, :timeout})

      _ ->
        Process.send_after(
          self(),
          {:retry,
           %{
             params
             | from: from,
               retry: %{retry | attempts: retry.attempts + 1}
           }, function},
          retry.interval
        )
    end

    {:noreply, state}
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

  defp grapheme_to_key(~s"\b"),
    do: {:raw, %{windowsVirtualKeyCode: 8, code: "Backspace", key: "Backspace"}}

  defp grapheme_to_key(key), do: {:text, key}
end
