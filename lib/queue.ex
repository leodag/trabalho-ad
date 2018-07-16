defmodule Queue do
  use Agent

  def start_link(_opts, gs_opts \\ []) do
    Agent.start_link(&:queue.new/0, gs_opts)
  end

  def put(queue, item = %Packet{}) do
    Agent.update(queue, &put_and_set_arrival(&1, item))
  end

  def put_r(queue, item = %Packet{}, time) do
    Agent.update(queue, &put_r_and_update_arrival(&1, item, time))
  end

  def get(queue, time) do
    Agent.get_and_update(queue, &get_and_update_time(&1, time))
  end

  def next_time(queue) do
    Agent.get(queue, &get_next_time(&1))
  end

  def len(queue) do
    Agent.get(queue, &:queue.len(&1))
  end

  defp get_next_time(queue) do
    head = :queue.peek(queue)

    case head do
      {:value, %Packet{time: time}} ->
        time

      # :empty
      _ ->
        head
    end
  end

  defp put_and_set_arrival(queue, item) do
    item = %{item | last_queue_arrival: item.time}
    :queue.in(item, queue)
  end

  defp put_r_and_update_arrival(queue, item, time) do
    item = %{item | last_queue_arrival: time}
    :queue.in_r(item, queue)
  end

  defp get_and_update_time(queue, time) do
    case :queue.out(queue) do
      {{:value, packet}, new_queue} ->
        {{:value,
          %{packet | time_on_queue: packet.time_on_queue + time - packet.last_queue_arrival}},
         new_queue}

      other ->
        other
    end
  end
end
