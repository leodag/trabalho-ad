defmodule DataMaestro do
  use GenServer

  @moduledoc """
  Modulo responsavel por armazer e ocmpuitar estatisticas quando cada evento acontece
  Irá receber através do handle_call os seguintes dados:

  evento -> tipo de evento que acontece
  packet -> pacote associado ao evento
  voice_queue_size -> numero de pacotes na fila de voz
  data_queue_size -> numero de pacotes na fila de dados
  time -> tempo atual do simulador

  um pacote tem a seguinte estrutura

  %Packet{
  first_in_period -> se ele for o primeiro do periodo ocupado
  from -> pid do gerador que o gerou
  generator_id -> id do gerador que o gerou
  last: -> se ele e o ultimo de um periodo ocupado
  last_queue_arrival -> ultima vez que ele 
  size -> tamanho do pacote
  time -> tempo da simulacao
  time_on_queue -> tempo na fila
  time_on_server -> tempo no servidor
  }
  """

  defstruct [:data_stats, :voice_stats, :interval_stats]

  @impl true
  def init(starting_time) do
    {:ok, mean_server} = GenServer.start_link(AverageTimeCalc, [])
    {:ok, mean_queue} = GenServer.start_link(AverageTimeCalc, [])
    {:ok, mean_total} = GenServer.start_link(AverageTimeCalc, [])
    {:ok, mean_number} = GenServer.start_link(AverageNumberCalc, starting_time)

    #vai manter as médias de dados
    data_stats = %{
      mean_server: mean_server,
      mean_queue: mean_queue,
      mean_total: mean_total,
      mean_number: mean_number
    }

    {:ok, mean_server} = GenServer.start_link(AverageTimeCalc, [])
    {:ok, mean_queue} = GenServer.start_link(AverageTimeCalc, [])
    {:ok, mean_total} = GenServer.start_link(AverageTimeCalc, [])
    {:ok, mean_number} = GenServer.start_link(AverageNumberCalc, starting_time)

    #Vai manter as médias de voz
    voice_stats = %{
      mean_server: mean_server,
      mean_queue: mean_queue,
      mean_total: mean_total,
      mean_number: mean_number
    }

    interval_stats = 
      List.to_tuple(
        for _ <- 1..30 do
          {:ok, pid} = GenServer.start_link(AverageTimeCalc, [])
          pid
        end
      )

    {:ok, %DataMaestro{
      data_stats: data_stats, 
      voice_stats: voice_stats,
      interval_stats: interval_stats
      }
    }
  end

  @impl true
  def handle_call(:size, _from, struct) do
    {:reply, tuple_size(struct.interval_stats), struct}
  end
 
  #retorna as medias dos tempos e filas de voz
  @impl true
  def handle_call(:voice_stats, _from, struct) do
    mean_server = GenServer.call(struct.voice_stats.mean_server, :mean)
    mean_queue = GenServer.call(struct.voice_stats.mean_queue, :mean)
    mean_total = GenServer.call(struct.voice_stats.mean_total, :mean)
    mean_number = GenServer.call(struct.voice_stats.mean_number, :mean)
    ret = %{ 
      mean_server: mean_server, 
      mean_queue: mean_queue, 
      mean_total: mean_total,
      mean_number: mean_number 
    }
    {:reply, ret, struct}
  end

  #retorna as medias dos tempos e filas de dados
  @impl true
  def handle_call(:data_stats, _from, struct) do
    mean_server = GenServer.call(struct.data_stats.mean_server, :mean)
    mean_queue = GenServer.call(struct.data_stats.mean_queue, :mean)
    mean_total = GenServer.call(struct.data_stats.mean_total, :mean)
    mean_number = GenServer.call(struct.data_stats.mean_number, :mean)
    ret = %{ 
      mean_server: mean_server, 
      mean_queue: mean_queue, 
      mean_total: mean_total,
      mean_number: mean_number 
    }

    {:reply, ret, struct}
  end

  #pega os dados de uma chegada de voz
  @impl true
  def handle_cast({:voice_arrival, _, voice_queue_size, data_queue_size, time}, struct) do
    default_updates(voice_queue_size, data_queue_size, time, struct)

    {:noreply, struct}
  end

  #pega os dados de uma chegada de dados
  @impl true
  def handle_cast({:data_arrival, _, voice_queue_size, data_queue_size, time}, struct) do
    default_updates(voice_queue_size, data_queue_size, time, struct)

    {:noreply, struct}
  end

  #pega os dados de um comeco de servico de dados
  @impl true
  def handle_cast({:data_serve, _, voice_queue_size, data_queue_size, time}, struct) do
    default_updates(voice_queue_size, data_queue_size, time, struct)

    {:noreply, struct}
  end

  @impl true
  def handle_cast({:voice_serve, _, voice_queue_size, data_queue_size, time}, struct) do
    default_updates(voice_queue_size, data_queue_size, time, struct)

    {:noreply, struct}
  end

  #updates dos dados que todos tem que fazer
  def default_updates(voice_queue_size, data_queue_size, time, struct) do
    data_pid = struct.data_stats.mean_number
    voice_pid = struct.voice_stats.mean_number

    GenServer.cast(voice_pid, {:value, voice_queue_size, time})
    GenServer.cast(data_pid, {:value, data_queue_size, time})
  end
end
