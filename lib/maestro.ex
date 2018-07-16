defmodule Maestro do
  def start_link(opts) do
    spawn_link(fn -> maestro(opts) end)
  end

  def init(opts) do
    voice_generator_count = Keyword.get(opts, :voice_generators, 30)
    data_generator_count = Keyword.get(opts, :data_generators, 1)
    preemptible = Keyword.get(opts, :preemptible, false)
    bandwidth = Keyword.get(opts, :bandwidth, 2_000_000)
    rho = Keyword.get(opts, :rho_percent, 10)

    # 755 é o tamanho médio de um pacote calculado utilizando
    # 0.3 * 64 + (Distributions.data_size_cdf(512) - 0.1 - 0.3) * 288 + 0.1 * 512
    # + (0.7 - Distributions.data_size_cdf(512)) * 1006 + 0.3 * 1500
    lambda_data = bandwidth * rho / 100 / (755 * 8)

    # Array de pids dos nossos geradores de voz
    voice_generators =
      for n <- 1..voice_generator_count do
        {:ok, pid} = VoiceGenerator.start_link(generator_id: n)
        pid
      end

    # Utilizamos o voice_queue como "funil" para tratarmos todoso nossos geradores
    # de pacotes como um só - dele, sempre recebemos o próximo evento dentre todos
    # os geradores.
    {:ok, _} = HeapPacketQueue.start_link([generators: voice_generators], name: VoiceSource)

    # Realizamos o mesmo processo para os geradores de dados
    data_generators =
      for _ <- 1..data_generator_count do
        {:ok, pid} = DataGenerator.start_link(lambda: lambda_data)
        pid
      end

    {:ok, _} = HeapPacketQueue.start_link([generators: data_generators], name: DataSource)

    {:ok, _} = Queue.start_link([], name: VoiceQueue)
    {:ok, _} = Queue.start_link([], name: DataQueue)

    {:ok, _} = Server2.start_link([bandwidth: bandwidth], name: Server)

    {:ok, _} = EventStats.start_link([voice_generators: voice_generator_count], name: EventStats)

    preemptible
  end

  def maestro(opts) do
    components = init(opts)

    loop(0, components, 0)
  end

  # Retorna o menor valor de um vetor
  def min_v([x | xs]) do
    Enum.reduce(xs, x, &min(&1, &2))
  end

  # Esta função determina qual será a próxima ação tomada e o momento no qual ela
  # ocorrerá, de acordo com os estados dos geradores, das filas e do servidor.

  # Assinatura legível da função:
  # def next_event(time, voice_arrival, data_arrival,
  # voice_serve, data_serve, server_state, preemptible)
  # server_state = (:empty | {:serving, type, server_departure})

  # Servidor vazio, pacote de voz esperando
  def next_event(t, _v_a, _d_a, voice_serve, _d_s, :empty, _p)
      when voice_serve <= t do
    {t, :voice_serve}
  end

  # Servidor vazio, pacote de dados esperando
  def next_event(t, _v_a, _d_a, _v_s, data_serve, :empty, _p)
      when data_serve <= t do
    {t, :data_serve}
  end

  # Servidor vazio, nenhum pacote esperando: pulamos para o próximo
  # momento no qual acontecerá algo
  def next_event(_t, v_a, d_a, v_s, d_s, :empty, _p) do
    next_time = min_v([v_a, d_a, v_s, d_s])

    next_event =
      cond do
        next_time == v_a -> :voice_arrival
        next_time == d_a -> :data_arrival
        next_time == v_s -> :voice_serve
        next_time == d_s -> :data_serve
      end

    {next_time, next_event}
  end

  # Servidor ocupado e não preemptível: não podemos começar a servir
  def next_event(_t, v_a, d_a, _v_s, _d_s, {:serving, s_d, type}, false) do
    next_time = min_v([v_a, d_a, s_d])

    next_event =
      cond do
        next_time == v_a -> :voice_arrival
        next_time == d_a -> :data_arrival
        next_time == s_d and type == :voice -> :voice_departure
        next_time == s_d and type == :data -> :data_departure
      end

    {next_time, next_event}
  end

  # Servidor ocupado e preemptível: não podemos começar a servir dados,
  # mas podemos começar a servir voz
  def next_event(_t, v_a, d_a, v_s, _d_s, {:serving, s_d, type}, true) do
    next_time =
      if type == :voice do
        min_v([v_a, d_a, s_d])
      else
        min_v([v_a, d_a, v_s, s_d])
      end

    next_event =
      cond do
        next_time == v_a -> :voice_arrival
        next_time == d_a -> :data_arrival
        next_time == s_d and type == :voice -> :voice_departure
        next_time == s_d and type == :data -> :data_departure
        next_time == v_s -> :interrupt_data
      end

    {next_time, next_event}
  end

  def loop(time, preemptible, departures) when is_number(time) and is_boolean(preemptible) do
    IO.puts(
      to_string(time)
      <> " v_q:"
      <> to_string(Queue.len(VoiceQueue))
      <> " d_q:" <> to_string(Queue.len(DataQueue))
    )

    voice_arrival = PacketGenerator.next_time(VoiceSource)
    data_arrival = PacketGenerator.next_time(DataSource)

    voice_serve = Queue.next_time(VoiceQueue)
    data_serve = Queue.next_time(DataQueue)

    server_state = Server2.status(Server)

    IO.inspect(departures)
    if rem(departures, 1000) == 0 do
      if EventStats.should_stop(EventStats) do
	IO.inspect(EventStats.voice_confidence_intervals(EventStats))
	exit(:normal)
      end
    end

    {next_time, next_event} =
      next_event(
        time,
        voice_arrival,
        data_arrival,
        voice_serve,
        data_serve,
        server_state,
        preemptible
      )

    packet =
      case next_event do
	:voice_arrival ->
          #IO.puts("v_a")
          voice_arrival()

	:data_arrival ->
          #IO.puts("d_a")
          data_arrival()

	:voice_serve ->
          #IO.puts("v_s")
          voice_serve(next_time)

	:data_serve ->
          #IO.puts("d_s")
          data_serve(next_time)

	:voice_departure ->
          #IO.puts("v_d" <> to_string(time))
          voice_departure()

	:data_departure ->
          #IO.puts("d_d")
	  departures = departures + 1
          data_departure()

	:interrupt_data ->
          #IO.puts("i_d")
	  departures = departures + 1
          interrupt_data(next_time)
      end

    voice_q_size = Queue.len(VoiceQueue)
    data_q_size = Queue.len(DataQueue)

    EventStats.event(
      EventStats,
      next_event,
      packet,
      voice_q_size,
      data_q_size,
      next_time
    )

    #IO.inspect(EventStats.voice_stats(EventStats))
    #IO.inspect(EventStats.data_stats(EventStats))
    #IO.inspect(EventStats.voice_confidence_intervals(EventStats))

    loop(next_time, preemptible, departures)
  end

  # chegada: obtém o pacote do gerador, e insere no final da fila
  def voice_arrival() do
    packet = PacketGenerator.get_packet(VoiceSource)
    packet = %{packet | last_queue_arrival: packet.time}
    Queue.put(VoiceQueue, packet)

    packet
  end

  def data_arrival() do
    packet = PacketGenerator.get_packet(DataSource)
    packet = %{packet | last_queue_arrival: packet.time}
    Queue.put(DataQueue, packet)

    packet
  end

  # início do serviço: retira da fila e coloca no servidor
  def voice_serve(time) do
    {:value, packet} = Queue.get(VoiceQueue, time)
    Server2.begin_serve(Server, time, :voice, packet)

    packet
  end

  def data_serve(time) do
    {:value, packet} = Queue.get(DataQueue, time)
    Server2.begin_serve(Server, time, :data, packet)

    packet
  end

  # saída: retira o pacote do servidor
  def voice_departure() do
    _packet = Server2.end_serve(Server)
  end

  def data_departure() do
    _packet = Server2.end_serve(Server)
  end

  # interrompe um pacote de dados: retira do servidor e retorna
  # ao começo da fila
  def interrupt_data(time) do
    packet = Server2.interrupt_serve(Server, time)
    Queue.put_r(DataQueue, packet, time)

    packet
  end
end
