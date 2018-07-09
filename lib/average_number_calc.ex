defmodule AverageNumberCalc do
  use GenServer

  @z_value 1.645

  defstruct(
    partial_sum_area: 0,
    partial_sum_squares: 0,
    time: 0,
    last_entry: 0
  )

  @impl true
  def init(_) do
    {:ok, %AverageNumberCalc{}}
  end

  @impl true
  def handle_call(:time, _from, struct) do
    {:reply, struct.time, struct}
  end

  @impl true
  def handle_call(:partial_sum, _from, struct) do
    {:reply, struct.partial_sum_area, struct}
  end

  @impl true
  def handle_call(:mean, _from, struct) do
    {:reply, mean(struct), struct}
  end

  # @impl true
  # def handle_call(:std_deviation, _from, struct) do
  #   {:reply, std_deviation(struct), struct}
  # end
  #
  # def handle_call(:interval, _from, struct) do
  #   {:reply, interval(struct), struct}
  # end
  #
  @impl true
  def handle_cast({:value, number, time}, struct) do
    time_delta = time - struct.last_entry
    area = number * time_delta
    updated_struct = %AverageNumberCalc{
      partial_sum_area: struct.partial_sum_area + area,
      partial_sum_squares: struct.partial_sum_squares + :math.pow(area, 2),
      time: struct.time + time_delta,
      last_entry: time
    }
    {:noreply, updated_struct}
  end
  #
  # defp interval(struct) do
  #   bound = @z_value * (std_deviation(struct) / :math.sqrt(struct.count))
  #   upper_bound = mean(struct) + bound
  #   lower_bound = mean(struct) - bound
  #   {lower_bound, upper_bound}
  # end
  #
  defp mean(struct) do
    if struct.time === 0 do
      0
    end
    struct.partial_sum_area / struct.time
  end
  #
  # defp std_deviation(struct) do
  #   :math.sqrt(variance(struct))
  # end
  #
  # defp variance(struct) do
  #   partial_sum_squares = struct.partial_sum_squares / (struct.count - 1)
  #   square_of_sum = :math.pow(struct.partial_sum, 2) / (struct.count * (struct.count - 1))
  #   partial_sum_squares - square_of_sum
  # end
end

