defmodule Maestro do
  def start_link(opts) do
    spawn_link fn -> maestro(opts) end
  end

  def init(opts) do
    voice_generator_count = Keyword.get(opts, :voice_generators, 1)
    data_generator_count = Keyword.get(opts, :data_generators, 1)
    preemptible = Keyword.get(opts, :preemptible, false)
    bandwidth = Keyword.get(opts, :bandwidth, 2_000_000)
    rho = Keyword.get(opts, :rho_percent, 10)

    # 755 é o tamanho médio de um pacote calculado utilizando
    # 0.3 * 64 + (Distributions.data_size_cdf(512) - 0.1 - 0.3) * 288 + 0.1 * 512
    # + (0.7 - Distributions.data_size_cdf(512)) * 1006 + 0.3 * 1500
    lambda = (bandwidth * rho / 100) / 755

    # Array de pids dos nossos geradores de voz
    voice_generators = for _ <- 1..voice_generator_count do
      {:ok, pid} = VoiceGenerator.start_link([])
      pid
    end

    # Utilizamos o voice_queue como "funil" para tratarmos todoso nossos geradores
    # de pacotes como um só - dele, sempre recebemos o próximo evento dentre todos
    # os geradores.
    {:ok, voice_source} = HeapPacketQueue.start_link([generators: voice_generators])

    # Realizamos o mesmo processo para os geradores de dados
    data_generators = for _ <- 1..data_generator_count do
      {:ok, pid} = DataGenerator.start_link([lambda: lambda])
      pid
    end

    {:ok, data_source} = HeapPacketQueue.start_link([generators: data_generators])

    {:ok, voice_queue} = Queue.start_link([])
    {:ok, data_queue} = Queue.start_link([])

    {:ok, server} = Server2.start_link([bandwidth: bandwidth])

    %Components{voice_source: voice_source,
                data_source: data_source,
                voice_queue: voice_queue,
                data_queue: data_queue,
                server: server,
		preemptible: preemptible}
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
  when voice_serve < t do
    :voice_serve
  end

  # Servidor vazio, pacote de dados esperando
  def next_event(t, _v_a, _d_a, _v_s, data_serve, :empty, _p)
  when data_serve < t do
    :data_serve
  end

  #def next_event(t, _v_a, _d_a, _v_s, _d_s, {:serving, s_d, :data}, true) when v_s < resto

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

  # Servidor ocupado: não podemos começar a servir
  def next_event(_t, v_a, d_a, _v_s, _d_s, {:serving, s_d, type}, _p) do
    next_time = min_v([v_a, d_a, s_d])

    cond do
      next_time == v_a -> :voice_arrival
      next_time == d_a -> :data_arrival
      next_time == s_d and type == :voice -> :voice_departure
      next_time == s_d and type == :data -> :data_departure
    end
  end

  def loop(time, components = %Components{}) do
    IO.puts to_string(time) <> " v_q:" <> to_string(Queue.len(components.voice_queue)) <> " d_q:" <> to_string(Queue.len(components.data_queue))

    voice_arrival = PacketGenerator.next_time(components.voice_source)
    data_arrival = PacketGenerator.next_time(components.data_source)

    voice_serve = Queue.next_time(components.voice_queue)
    data_serve = Queue.next_time(components.data_queue)

    server_state = Server2.status(components.server)

    next_event = next_event(time, voice_arrival, data_arrival,
      voice_serve, data_serve, server_state, components.preemptible)

    case next_event do
      :voice_arrival ->
	IO.puts "v_a"
	arrival(components.voice_source, components.voice_queue)
	loop(voice_arrival, components)
      :data_arrival ->
	IO.puts "d_a"
	arrival(components.data_source, components.data_queue)
	loop(data_arrival, components)
      :voice_serve ->
	IO.puts "v_s"
	serve_start = max(voice_serve, time)
	voice_serve(serve_start, components.voice_queue, components.server)
	loop(voice_serve, components)
      :data_serve ->
	IO.puts "d_s"
	serve_start = max(data_serve, time)
	data_serve(serve_start, components.data_queue, components.server)
	loop(data_serve, components)
      :voice_departure ->
	IO.puts "v_d"
	{:serving, serve_end, :voice} = server_state
	voice_departure(components.server)
	loop(serve_end, components)
      :data_departure ->
	IO.puts "d_d"
	{:serving, serve_end, :data} = server_state
	data_departure(components.server)
	loop(serve_end, components)
    end
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
    Server2.end_serve(server)
  end

  def data_departure(server) do
    Server2.end_serve(server)
  end
end
