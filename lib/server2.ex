defmodule Server2 do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    bandwidth = Keyword.get(opts, :bandwidth, 2_000_000) # 2 Mbps
    {:ok, {bandwidth, :empty}}
  end

  def begin_serve(server, serve_start, type, packet) do
    GenServer.call(server, {:begin_serve, serve_start, type, packet})
  end

  def end_serve(server) do
    GenServer.call(server, :end_serve)
  end

  def status(server) do
    GenServer.call(server, :status)
  end

  def handle_call({:begin_serve, time, type, packet = %Packet{}}, _from, {bandwidth, :empty}) do
    serve_end = time + packet.size/bandwidth
    {:reply, :ok, {bandwidth, {:serving, serve_end, type, packet}}}
  end

  def handle_call(:end_serve, _from, {bandwidth, {:serving, _serve_end, _type, _packet}}) do
    {:reply, :ok, {bandwidth, :empty}}
  end

  def handle_call(:status, _from, state = {_bandwidth, :empty}) do
    {:reply, :empty, state}
  end

  def handle_call(:status, _from, state = {_bandwidth, {:serving, serve_end, type, _packet}}) do
    {:reply, {:serving, serve_end, type}, state}
  end
end
