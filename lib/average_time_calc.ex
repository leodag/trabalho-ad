defmodule AverageTimeCalc do
  use GenServer

  @z_value 1.645

  defstruct(
    partial_sum: 0,
    partial_sum_squares: 0,
    count: 0
  )

  @impl true
  def init(_) do
    {:ok, %AverageTimeCalc{}}
  end

  @impl true
  def handle_call(:count, _from, struct) do
    {:reply, struct.count, struct}
  end

  @impl true
  def handle_call(:partial_sum, _from, struct) do
    {:reply, struct.partial_sum, struct}
  end

  @impl true
  def handle_call(:mean, _from, struct) do
    {:reply, mean(struct), struct}
  end

  @impl true
  def handle_call(:std_deviation, _from, struct) do
    {:reply, std_deviation(struct), struct}
  end

  def handle_call(:interval, _from, struct) do
    {:reply, interval(struct), struct}
  end

  @impl true
  def handle_cast({:value, time}, struct) do
    updated_struct = %AverageTimeCalc{
      partial_sum: struct.partial_sum + time,
      partial_sum_squares: struct.partial_sum_squares + :math.pow(time, 2),
      count: struct.count + 1
    }
    {:noreply, updated_struct}
  end

  defp interval(struct) do
    bound = @z_value * (std_deviation(struct) / :math.sqrt(struct.count))
    upper_bound = mean(struct) + bound
    lower_bound = mean(struct) - bound
    {lower_bound, upper_bound}
  end

  defp mean(struct) do
    if struct.count === 0 do
      0
    end
    struct.partial_sum / struct.count
  end

  defp std_deviation(struct) do
    :math.sqrt(variance(struct))
  end

  defp variance(struct) do
    partial_sum_squares = struct.partial_sum_squares / (struct.count - 1)
    square_of_sum = :math.pow(struct.partial_sum, 2) / (struct.count * (struct.count - 1))
    partial_sum_squares - square_of_sum
  end
end
