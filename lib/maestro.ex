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
    lambda_data = bandwidth * rho / 100 / 755

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

    preemptible
  end

  def maestro(opts) do
    components = init(opts)

    loop(0, components)
  end

  # Retorna o menor valor de um vetor
  def min_v([x | xs]) do
    Enum.reduce(xs, x, &min(&1, &2))
  end

  # Esta função determina qual será a próxima ação tomada, de acordo com
  # os estados dos geradores, das filas e do servidor.

  # Assinatura legível da função:
  # def next_event(time, voice_arrival, data_arrival,
  # voice_serve, data_serve, server_state)
  # server_state = (:empty | {:serving, type, server_departure})

  # Servidor vazio, pacote de voz esperando
  def next_event(t, _v_a, _d_a, voice_serve, _d_s, :empty, _p)
      when voice_serve <= t do
    :voice_serve
  end

  # Servidor vazio, pacote de dados esperando
  def next_event(t, _v_a, _d_a, _v_s, data_serve, :empty, _p)
      when data_serve <= t do
    :data_serve
  end

  # def next_event(t, _v_a, _d_a, _v_s, _d_s, {:serving, s_d, :data}, true) when v_s < resto

  # Servidor vazio, nenhum pacote esperando: pulamos para o próximo
  # momento no qual acontecerá algo
  def next_event(_t, v_a, d_a, v_s, d_s, :empty, _p) do
    next_time = min_v([v_a, d_a, v_s, d_s])

    cond do
      next_time == v_a -> :voice_arrival
      next_time == d_a -> :data_arrival
      next_time == v_s -> :voice_serve
      next_time == d_s -> :data_serve
    end
  end

  # Servidor ocupado e não preemptível: não podemos começar a servir
  def next_event(_t, v_a, d_a, _v_s, _d_s, {:serving, s_d, type}, false) do
    next_time = min_v([v_a, d_a, s_d])

    cond do
      next_time == v_a -> :voice_arrival
      next_time == d_a -> :data_arrival
      next_time == s_d and type == :voice -> :voice_departure
      next_time == s_d and type == :data -> :data_departure
    end
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

    cond do
      next_time == v_a -> :voice_arrival
      next_time == d_a -> :data_arrival
      next_time == s_d and type == :voice -> :voice_departure
      next_time == s_d and type == :data -> :data_departure
      next_time == v_s -> :interrupt_data
    end
  end

  def loop(time, preemptible) when is_number(time) and is_boolean(preemptible) do
    IO.puts(
      to_string(time) <>
        " v_q:" <> to_string(Queue.len(VoiceQueue)) <> " d_q:" <> to_string(Queue.len(DataQueue))
    )

    voice_arrival = PacketGenerator.next_time(VoiceSource)
    data_arrival = PacketGenerator.next_time(DataSource)

    voice_serve = Queue.next_time(VoiceQueue)
    data_serve = Queue.next_time(DataQueue)

    server_state = Server2.status(Server)

    next_event =
      next_event(
        time,
        voice_arrival,
        data_arrival,
        voice_serve,
        data_serve,
        server_state,
        preemptible
      )

    case next_event do
      :voice_arrival ->
        IO.puts("v_a")
        arrival(VoiceSource, VoiceQueue)
        voice_arrival

      :data_arrival ->
        IO.puts("d_a")
        arrival(DataSource, DataQueue)
        data_arrival

      :voice_serve ->
        IO.puts("v_s")
        serve_start = max(voice_serve, time)
        voice_serve(serve_start, VoiceQueue, Server)
        serve_start

      :data_serve ->
        IO.puts("d_s")
        serve_start = max(data_serve, time)
        data_serve(serve_start, DataQueue, Server)
        serve_start

      :voice_departure ->
        IO.puts("v_d")
        {:serving, serve_end, :voice} = server_state
        voice_departure(Server)
        serve_end

      :data_departure ->
        IO.puts("d_d")
        {:serving, serve_end, :data} = server_state
        data_departure(Server)
        serve_end

      :interrupt_data ->
        IO.puts("i_d")
        interrupt_data(voice_serve)
        voice_serve
    end
    |> loop(preemptible)
  end

  def arrival(source, queue) do
    packet = PacketGenerator.get_packet(source)
    packet = %{packet | last_queue_arrival: packet.time}
    Queue.put(queue, packet)
  end

  def voice_serve(time, queue, server) do
    {:value, packet} = Queue.get(queue, time)
    Server2.begin_serve(server, time, :voice, packet)
  end

  def data_serve(time, queue, server) do
    {:value, packet} = Queue.get(queue, time)
    Server2.begin_serve(server, time, :data, packet)
  end

  def voice_departure(server) do
    packet = Server2.end_serve(server)

    IO.inspect(packet)
  end

  def data_departure(server) do
    packet = Server2.end_serve(server)

    IO.inspect(packet)
  end

  def interrupt_data(time) do
    packet = Server2.interrupt_serve(Server, time)

    Queue.put_r(DataQueue, packet, time)
  end
end
