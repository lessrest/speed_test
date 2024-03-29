defmodule SpeedTest.Page.Session do
  @moduledoc ~S"""
  Manages individual browser pages
  """
  use GenServer

  require Logger

  alias ChromeRemoteInterface.{HTTP, PageSession, RPC, Server}
  alias SpeedTest.Page.Registry
  alias SpeedTest.{Cookie, Retry}

  @timeout :timer.seconds(30)
  @base_url Application.get_env(:speed_test, :base_url) || ""

  # Client functions

  # Server functions

  @impl true
  def init(%{page: page} = state) do
    # Register the process globally
    {:ok, _registry} = Registry.register(page)

    server = state[:server] || %Server{
      host: "localhost",
      port: Keyword.fetch!(Application.fetch_env!(:chroxy, Chroxy.Endpoint), :port)
    }
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
      |> Map.put(:mouse_position, {0, 0})

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
      {:reply, {:ok, decoded}, state}
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
      {:reply, {:ok, decoded}, state}
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
                RPC.DOM.getDocument(pid, %{}, options),
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
      {:reply, {:ok, value}, state}
    else
      nil ->
        {:reply, {:error, :notfound}, state}
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
        %{pid: pid, mouse_position: {mx, my}} = state
      ) do
    click_count = params[:click_count] || 1

    with {:ok, %{"result" => %{"model" => %{"content" => quad}}}} <-
           RPC.DOM.getBoxModel(pid, %{"nodeId" => node_id}, options),
         {:ok, {x, y}} <- calculate_center(quad),
         {:ok, _result} <-
           pid
           |> RPC.Input.dispatchMouseEvent(%{
             "type" => "mouseMoved",
             "button" => "left",
             "x" => mx + (x - mx),
             "y" => my + (y - my)
           }),
         {:ok, _result} <-
           RPC.Input.dispatchMouseEvent(pid, %{
             "type" => "mousePressed",
             "button" => "left",
             "clickCount" => click_count,
             "x" => x,
             "y" => y
           }),
         {:ok, _result} <-
           RPC.Input.dispatchMouseEvent(pid, %{
             "type" => "mouseReleased",
             "button" => "left",
             "clickCount" => click_count,
             "x" => x,
             "y" => y
           }) do
      {:reply, :ok, %{state | mouse_position: {x, y}}}
    else
      nil ->
        {:reply, :notfound, state}
    end
  end

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

  def handle_call({:get_cookie, name, options}, _from, %{pid: pid} = state) do
    with {:ok, %{"result" => %{"cookies" => cookies}}} <-
           RPC.Network.getCookies(
             pid,
             %{},
             options
           ),
         cookie <- Enum.find(cookies, &(&1["name"] == name)) do
      {:reply,
       %Cookie{
         domain: cookie["domain"],
         expires: cookie["expires"],
         http_only: cookie["httpOnly"],
         name: cookie["name"],
         path: cookie["path"],
         same_site: cookie["sameSite"],
         secure: cookie["secure"],
         value: cookie["value"]
       }, state}
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
           |> Enum.find(fn %{"request" => request, "response" => response} ->
             request["method"] == method and
               String.contains?(request["url"], "#{@base_url}#{url}") and response != %{}
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
    case state.network_requests[request_id] do
      nil ->
        {:noreply, state}

      _ ->
        {:noreply, put_in(state, [:network_requests, request_id, "response"], response)}
    end
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

  defp calculate_center([x1, y1, x2, y2, x3, y3, x4, y4]) do
    x = (x1 + x2 + x3 + x4) / 4
    y = (y1 + y2 + y3 + y4) / 4

    {:ok, {round(x), round(y)}}
  end
end
