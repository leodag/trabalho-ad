defmodule FilaSimulada do
  use Agent

  def start_link(_opts) do
    Agent.start_link(&PQueue2.new/0)
  end

  def put(queue, pid, time) do
    Agent.update(queue, &PQueue2.put(&1, pid, time))
  end

  def pop_and_replace(queue) do
    case PQueue2.pop_with_priority(queue) do
      {{pid, time}, queue} ->
	send pid, {:get, self()}
	receive do
	  {:put, time, pid} -> {:put, time, pid}
	end
    end
  end

  def get(queue) do
    case Agent.get_and_update(queue, &PQueue2.pop_with_priority(&1)) do
      {pid, time} ->
	{:reply, time, pid}
      _ ->
	:empty
    end
  end
end
