defmodule FilaSimulada do
  use Agent

  def start_link(_opts) do
    Agent.start_link(&PQueue2.new/0)
  end

  def put(queue, pid, priority) do
    Agent.update(queue, &PQueue2.put(&1, pid, priority))
  end

  def get(queue) do
    case Agent.get_and_update(queue, &PQueue2.pop_with_priority(&1)) do
      {pid, prio} ->
        {:reply, pid, prio}
      _ ->
        :empty
    end
  end
end
