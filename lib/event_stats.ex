defmodule EventStats do
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

  def start_link(opts, gs_opts \\ []) do
    GenServer.start_link(__MODULE__, opts, gs_opts)
  end

  def event(server, event_type, packet, voice_q_size, data_q_size, time) do
    GenServer.cast(server, {event_type, packet, voice_q_size, data_q_size, time})
  end

  def voice_stats(server) do
    GenServer.call(server, :voice_stats)
  end

  def voice_confidence_intervals(server) do
    GenServer.call(server, :voice_confidence_intervals)
  end

  def data_confidence_intervals(server) do
    GenServer.call(server, :data_confidence_intervals)
  end

  def data_stats(server) do
    GenServer.call(server, :data_stats)
  end

  def should_stop(server) do
    GenServer.call(server, :should_stop)
  end

  def size(server) do
    GenServer.call(server, :size)
  end

  @impl true
  def init(opts) do
    starting_time = Keyword.get(opts, :starting_time, 0)
    voice_generator_count = Keyword.get(opts, :voice_generators, 30)

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
    {:ok, mean_interval_total} = GenServer.start_link(AverageTimeCalc, [])
    {:ok, mean_number} = GenServer.start_link(AverageNumberCalc, starting_time)

    #Vai manter as médias de voz
    voice_stats = %{
      mean_server: mean_server,
      mean_queue: mean_queue,
      mean_total: mean_total,
      mean_interval_total: mean_interval_total,
      mean_number: mean_number
    }

    interval_stats = 
      List.to_tuple(
        for _ <- 1..voice_generator_count do
          {:ok, pid} = GenServer.start_link(AverageTimeCalc, [])
          pid
        end
      )

    {:ok, %EventStats{
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
    mean_interval_total = GenServer.call(struct.voice_stats.mean_interval_total, :mean)
    mean_number = GenServer.call(struct.voice_stats.mean_number, :mean)

    ret = %{ 
      mean_server: mean_server, 
      mean_queue: mean_queue, 
      mean_total: mean_total,
      mean_interval_total: mean_interval_total,
      mean_number: mean_number 
    }
    {:reply, ret, struct}
  end

  def handle_call(:voice_confidence_intervals, _from, struct) do
    mean_server = GenServer.call(struct.voice_stats.mean_server, :interval)
    mean_queue = GenServer.call(struct.voice_stats.mean_queue, :interval)
    mean_total = GenServer.call(struct.voice_stats.mean_total, :interval)
    mean_interval_total = GenServer.call(struct.voice_stats.mean_interval_total, :interval)

    ret = %{ 
      mean_server_intervals: mean_server, 
      mean_queue_intervals: mean_queue, 
      mean_total_intervals: mean_total,
      mean_interval_total: mean_interval_total
    }
    {:reply, ret, struct}
  end

  def handle_call(:data_confidence_intervals, _from, struct) do
    mean_server = GenServer.call(struct.data_stats.mean_server, :interval)
    mean_queue = GenServer.call(struct.data_stats.mean_queue, :interval)
    mean_total = GenServer.call(struct.data_stats.mean_total, :interval)

    ret = %{ 
      mean_server_intervals: mean_server, 
      mean_queue_intervals: mean_queue, 
      mean_total_intervals: mean_total
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

  #retorna trrue se os valores da IC forem menores que 10% da media nas 
  #estatisticas de voz
  @impl true
  def handle_call(:should_stop, _from, struct) do
    mean_total = GenServer.call(struct.voice_stats.mean_total, :mean)

    {lower_total, higher_total} = GenServer.call(struct.voice_stats.mean_total, :interval)

    return_value = mean_total * 1.1 > higher_total and
                    mean_total * 0.9 < lower_total
    {:reply, return_value, struct}
  end


  #pega os dados de uma interrupcao de servico de dado
  @impl true
  def handle_cast({:interrupt_data, _, voice_queue_size, data_queue_size, time}, struct) do
    default_updates(voice_queue_size, data_queue_size, time, struct)

    {:noreply, struct}
  end

  #pega os dados de uma chegada de voz
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

  #pega os dados de um comeco de servico de voz
  @impl true
  def handle_cast({:voice_serve, packet, voice_queue_size, data_queue_size, time}, struct) do
    default_updates(voice_queue_size, data_queue_size, time, struct)

    id = packet.generator_id - 1
    interval_pid = elem(struct.interval_stats, id)

    is_first = packet.first_in_period === packet.time
    is_last = packet.last

    struct = 
      case {is_first, is_last} do
        {true, _} -> 
          #cria uma nova calculadora de media
          {:ok, new_pid} = GenServer.start_link(AverageTimeCalc, time)
          new_interval_stats = put_elem(struct.interval_stats, id, new_pid)

          #atualizar a struct
          put_in(struct.interval_stats, new_interval_stats)
        #ultimo pacote do periodo ocupado
        {false, true} -> 
          last_entry = GenServer.call(interval_pid, :last_entry)
          GenServer.cast(interval_pid, {:value, time - last_entry})

          partial_mean = GenServer.call(interval_pid, :mean)
          GenServer.cast(struct.voice_stats.mean_interval_total, {:value, partial_mean})

          struct
        _ ->
          last_entry = GenServer.call(interval_pid, :last_entry)
          GenServer.cast(interval_pid, {:value, time - last_entry})

          struct
      end

    {:noreply, struct}
  end

  #lida com os dados de uma partida de dados
  # Que sao o tempo que o pacote ficou na fila, no servidor e ao total
  @impl true
  def handle_cast({:data_departure, packet, voice_queue_size, data_queue_size, time}, struct) do
    default_updates(voice_queue_size, data_queue_size, time, struct)

    data_server_pid = struct.data_stats.mean_server
    data_queue_pid = struct.data_stats.mean_queue
    data_total_pid = struct.data_stats.mean_total

    GenServer.cast(data_server_pid, {:value, packet.time_on_server})
    GenServer.cast(data_queue_pid, {:value, packet.time_on_queue})
    GenServer.cast(data_total_pid, {:value,packet.time_on_queue + packet.time_on_server})

    {:noreply, struct}
  end

  #lida com os dados de uma partida de voz
  # Que sao o tempo que o pacote ficou na fila, no servidor e ao total
  @impl true
  def handle_cast({:voice_departure, packet, voice_queue_size, data_queue_size, time}, struct) do
    default_updates(voice_queue_size, data_queue_size, time, struct)

    voice_server_pid = struct.voice_stats.mean_server
    voice_queue_pid = struct.voice_stats.mean_queue
    voice_total_pid = struct.voice_stats.mean_total

    GenServer.cast(voice_server_pid, {:value, packet.time_on_server})
    GenServer.cast(voice_queue_pid, {:value, packet.time_on_queue})
    GenServer.cast(voice_total_pid, {:value,packet.time_on_queue + packet.time_on_server})

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
