defmodule Queue do
  use Agent
  def start_link(_opts) do
    Agent.start_link(&:queue.new/0)
  end

  def put(queue, item) do
    Agent.update(queue, &:queue.in(item, &1))
  end

  def put_r(queue, item) do
    Agent.update(queue, &:queue.in_r(item, &1))
  end

  def get(queue) do
    Agent.get_and_update(queue, &:queue.out(&1))
  end
end
