defmodule HeapPacketQueue do
  use GenServer

  def start_link(opts, gs_opts \\ []) do
    GenServer.start_link(__MODULE__, opts, gs_opts)
  end

  def init(opts) do
    packet_generators = Keyword.fetch!(opts, :generators)

    queue = Heap.new(&(&1.time < &2.time))

    packets =
      for generator <- packet_generators do
        PacketGenerator.get_packet(generator)
      end

    {:ok, Enum.into(packets, queue)}
  end

  def handle_call(:next_time, _from, queue) do
    {:reply, Heap.root(queue).time, queue}
  end

  def handle_call(:get_packet, from, queue) do
    {packet, queue} = Heap.split(queue)

    GenServer.reply(from, packet)

    new_packet = PacketGenerator.get_packet(packet.from)
    queue = Heap.push(queue, new_packet)

    {:noreply, queue}
  end
end
