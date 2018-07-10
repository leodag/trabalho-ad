defmodule PacketGenerator do
  use GenServer

  defstruct [:ppf_time, :ppf_size, :reply]

  # recebe duas ppf (inversa da cdf), uma para tamanho do pacote
  # e uma para incremento do tempo
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def get_packet(server) do
    GenServer.call(server, :get_packet)
  end

  def next_time(server) do
    GenServer.call(server, :next_time)
  end

  def delay(server, amount) do
    GenServer.call(server, {:delay, amount})
  end

  def init(opts) do
    ppf_time = Keyword.get(opts, :ppf_time, Distributions.constant(1))
    ppf_size = Keyword.get(opts, :ppf_size, Distributions.constant(1))

    # calculamos a chegada inicial
    reply = generate_packet(ppf_time, ppf_size, 0)
    {:ok, %PacketGenerator{ppf_time: ppf_time,
                           ppf_size: ppf_size,
                           reply: reply}}
  end

  # gera um numero na distribuição especificada
  defp generate_number(ppf) do
    ppf.(:rand.uniform())
  end

  # gera uma chegada
  defp generate_packet(ppf_time, ppf_size, prev_time) do
    %Packet{time: prev_time + generate_number(ppf_time),
            size: generate_number(ppf_size),
            from: self()
    }
  end

  def handle_call(:get_packet, from, state = %PacketGenerator{}) do
    GenServer.reply(from, state.reply)

    # calculamos depois de responder (e antes da próxima requisição)
    # para evitar atrasos desnecessários
    next = generate_packet(state.ppf_time, state.ppf_size, state.reply.time)

    # noreply, porque ja respondemos antes
    {:noreply, %{state | reply: next}}
  end

  def handle_call(:next_time, _from, state = %PacketGenerator{reply: next}) do
    {:reply, next.time, state}
  end

  def handle_call({:delay, amount}, _from, state = %PacketGenerator{}) do
	# atrasamos a chegada do pacote
	next = %Packet{state.reply | time: state.reply.time + amount}
	{:reply, :ok, %{state | reply: next}}
  end
end

defmodule VoiceGenerator do
  use GenServer

  defstruct [:packet_gen, :ppf_delay, :delay_chance]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    {:ok, packet_gen} = PacketGenerator.start_link([
      ppf_time: Distributions.constant(0.016), # 16 ms
      ppf_size: Distributions.constant(512),
    ])
    ppf_delay = Statistics.Distributions.Exponential.ppf(1/0.650) # media: 650 ms

    # atraso inicial
    delay(packet_gen, ppf_delay)

    {:ok, %VoiceGenerator{packet_gen: packet_gen,
			  ppf_delay: ppf_delay,
			  delay_chance: 1/22}}
  end

  # gera um numero na distribuição especificada
  defp generate_number(ppf) do
    ppf.(:rand.uniform())
  end

  defp delay(packet_gen, ppf_delay) do
    amount = generate_number(ppf_delay)
    PacketGenerator.delay(packet_gen, amount)
  end

  def handle_call(:get_packet, from, state = %VoiceGenerator{}) do
    # substitui o campo from para o pid deste processo
    reply = %{PacketGenerator.get_packet(state.packet_gen) | from: self()}
    GenServer.reply(from, reply)

    if :rand.uniform() < state.delay_chance do
      delay(state.packet_gen, state.ppf_delay)
    end

    {:noreply, state}
  end

  def handle_call(:next_time, _from, state = %VoiceGenerator{}) do
    {:reply, PacketGenerator.next_time(state.packet_gen)}
  end
end

defmodule DataGenerator do
  def start_link(_opts) do
    PacketGenerator.start_link([
      ppf_time: Statistics.Distributions.Exponential.ppf(1),
      ppf_size: Distributions.data_size(),
    ])
  end
end
