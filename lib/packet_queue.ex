defmodule PacketQueue do
  use Agent

  def initialize_queue(_) do
    Agent.start_link(fn ->
      Heap.new(&(&1.time < &2.time))
    end)
  end

  def size(queue) do
    Agent.get(queue, &Heap.size(&1))
  end

  def push(queue, event) do
    Agent.update(queue, &Heap.push(&1, event))
  end

  def head(queue) do
    Agent.get(queue, &Heap.root(&1))
  end

  def pop(queue) do
    Agent.get_and_update(queue, &Heap.split(&1))
  end
end
