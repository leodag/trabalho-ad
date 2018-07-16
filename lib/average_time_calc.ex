defmodule AverageTimeCalc do
  use GenServer

  @z_value 1.645

  defstruct(
    partial_sum: 0,
    partial_sum_squares: 0,
    count: 0,
    last_entry: 0
  )

  def start_link(opts, gs_opts \\ []) do
    GenServer.start_link(__MODULE__, opts, gs_opts)
  end

  @doc """
  Retorna no numero de entradas
  """
  def get_count(server) do
    GenServer.call(server, :count)
  end

  @doc """
  retorna a soma parcial das entradas
  """
  def get_partial_sum(server) do
    GenServer.call(server, :partial_sum)
  end

  @doc """
  retorna a media das entradas
  """
  def get_mean(server) do
    GenServer.call(server, :mean)
  end

  @doc """
  retorna o desvio padrão
  """
  def get_std_deviation(server) do
    GenServer.call(server, :std_deviation)
  end

  @doc """
  retorna o intervalo de confiança
  """
  def get_interval(server) do
    GenServer.call(server, :interval)
  end

  @doc """
  serve para adicionar as entradas
  """
  def put_value(server, value) do
    GenServer.cast(server, {:value, value})
  end

  @impl true
  def init(first) do
    case is_number(first) do
      true ->
        {:ok, %AverageTimeCalc{last_entry: first}}
      _ -> 
        {:ok, %AverageTimeCalc{last_entry: 0}}
    end
  end

  @impl true
  def handle_call(:count, _from, struct) do
    {:reply, struct.count, struct}
  end

  @impl true
  def handle_call(:last_entry , _from, struct) do
    {:reply, struct.last_entry, struct}
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
      count: struct.count + 1,
      last_entry: struct.last_entry + time
    }

    {:noreply, updated_struct}
  end

  #função privada para o calculo dos intervalos de confiança
  defp interval(struct) do
    case struct.count < 30 do
      true -> {:infinity, :infinity}
      _ -> 
        bound = @z_value * (std_deviation(struct) / :math.sqrt(struct.count))
        upper_bound = mean(struct) + bound
        lower_bound = mean(struct) - bound
        {lower_bound, upper_bound}
    end
  end

  #função privada para o calculo da media
  defp mean(struct) do
    case struct.count do
      0 -> 0
      _ -> struct.partial_sum / struct.count
    end
  end

  #função privada para o calculo do desvio padrão
  defp std_deviation(struct) do
    :math.sqrt(abs(variance(struct)))
  end

  #função privada para o calculo da variança
  defp variance(struct) do
    case struct.count do
      0 -> 0
      1 -> 0
      _ -> 
        partial_sum_squares = struct.partial_sum_squares / (struct.count - 1)
        square_of_sum = :math.pow(struct.partial_sum, 2) / (struct.count * (struct.count - 1))
        partial_sum_squares - square_of_sum
    end
  end
end

