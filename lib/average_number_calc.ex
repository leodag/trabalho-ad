defmodule AverageNumberCalc do
  use GenServer

  @moduledoc """
  Module feito para guardar e calcular media de
  métricas de quantidade. que envolvem calculo de
  area e divisão pelo tempo.
  """
  defstruct(
    partial_sum_area: 0, #mantem a soma parcial das areas
    partial_sum_squares: 0, #mantem a soma parcial ads areas ao quadrado
    count: 0, #mantem a quantidade de medições que foram recebidas
    time: 0, #matem o tempo total desde a primeira entrada
    last_entry: 0 #mantem o tempo que foi adicionado a ultima entrada
  )

  @doc """
  Começa a thread
  """
  def start_link(opts, gs_opts \\ []) do
    GenServer.start_link(__MODULE__, opts, gs_opts)
  end

  @doc """
  retorna o somátorio do tempo acumulado
  """
  def get_time(server) do
    GenServer.call(server, :time)
  end

  @doc """
  retorna o somátorio do da área acumulada
  """
  def get_partial_sum(server) do
    GenServer.call(server, :partial_sum)
  end

  @doc """
  retorna a media
  """
  def get_mean(server) do
    GenServer.call(server, :mean)
  end

  @doc """
  funçao que serve para receber os dados
  """
  def put_value(server, number, time) do
    GenServer.cast(server, {:value, number, time})
  end

  @impl true
  def init(time) do
    {:ok, %AverageNumberCalc{last_entry: time}}
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

  @doc """
  Função que atualia os valores de verdade na struct do modulo
  """
  @impl true
  def handle_cast({:value, number, time}, struct) do
    time_delta = time - struct.last_entry
    area = number * time_delta
    updated_struct = %AverageNumberCalc{
      partial_sum_area: struct.partial_sum_area + area,
      partial_sum_squares: struct.partial_sum_squares + :math.pow(area, 2),
      count: struct.count + 1,
      time: struct.time + time_delta,
      last_entry: time
    }
    {:noreply, updated_struct}
  end

  #função privada que calcula a media
  defp mean(struct) do
    if struct.time === 0 do
      0
    end
    struct.partial_sum_area / struct.time
  end

end

