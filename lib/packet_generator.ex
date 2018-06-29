defmodule PacketGenerator do
  use GenServer

  # recebe duas ppf (inversa da cdf), uma para tamanho do pacote
  # e uma para incremento do tempo
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end


  def init(opts) do
    ppf_time = Keyword.get(opts, :ppf_time, Distributions.constant(1))
    ppf_size = Keyword.get(opts, :ppf_size, Distributions.constant(1))

    # calculamos a chegada inicial
    reply = generate_packet(ppf_time, ppf_size, 0)
    {:ok, {ppf_time, ppf_size, reply}}
  end

  def get_packet(server) do
    GenServer.call(server, :get_packet)
  end

  def delay(server, amount) do
    GenServer.call(server, {:delay, amount})
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

  @impl
  def handle_call(:get_packet, from, {ppf_time, ppf_size, reply}) do
    GenServer.reply(from, reply)

    # calculamos depois de responder (e antes da próxima requisição)
    # para evitar atrasos desnecessários
    next = generate_packet(ppf_time, ppf_size, reply.time)

    # noreply, porque ja respondemos antes
    {:noreply, {ppf_time, ppf_size, next}}
  end

  @impl
  def handle_call({:delay, amount}, from, {ppf_time, ppf_size, reply}) do
	# atrasamos a chegada do pacote
	next = %Packet{reply | time: reply.time + amount}
	{:reply, :ok, {ppf_time, ppf_size, next}}
  end
end


defmodule VoiceGenerator do
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    {:ok, packet_gen} = PacketGenerator.start_link([
      ppf_time: Distributions.constant(16_000),
      ppf_size: Distributions.constant(512),
    ])
    ppf_delay = Statistics.Distributions.Exponential.ppf(1/650_000)

    {:ok, {packet_gen, ppf_delay, 1/22}}
  end

  # gera um numero na distribuição especificada
  defp generate_number(ppf) do
    ppf.(:rand.uniform())
  end

  defp delay(packet_gen, ppf_delay) do
    amount = generate_number(ppf_delay)
    PacketGenerator.delay(packet_gen, amount)
  end

  @impl
  def handle_call(:get_packet, from, {packet_gen, ppf_delay, delay_chance}) do
    GenServer.reply(from, PacketGenerator.get_packet(packet_gen))

    if :rand.uniform() < delay_chance do
      delay(packet_gen, ppf_delay)
    end

    {:noreply, {packet_gen, ppf_delay, delay_chance}}
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
