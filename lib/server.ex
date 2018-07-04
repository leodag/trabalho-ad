defmodule Server do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    {:ok, :empty}
  end

  def handle_call({:start_serve, packet}, from, :empty) do
    {:reply, :ok, {:serving, packet}}
  end

  def handle_call(:end_serve, from, {:serving, packet}) do
    {:reply, packet, :empty}
  end
end
