defmodule PacketGenerator do
  use GenServer

  # recebe duas ppf (inversa da cdf), uma para tamanho do pacote
  # e uma para incremento do tempo
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    type = Keyword.get(opts, :type, :data)
    ppf_time = Keyword.get(opts, :ppf_time, Distributions.constant(1))
    ppf_size = Keyword.get(opts, :ppf_size, Distributions.constant(1))

    # calculamos a chegada inicial
    reply = generate_packet(type, ppf_time, ppf_size, 0)
    {:ok, {type, ppf_time, ppf_size, reply}}
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
  defp generate_packet(type, ppf_time, ppf_size, prev_time) do
    Packet.new(type,
      prev_time + generate_number(ppf_time),
      generate_number(ppf_size))
  end

  def handle_call(:get_packet, from, {type, ppf_time, ppf_size, reply}) do
    GenServer.reply(from, reply)

    # calculamos depois de responder (e antes da próxima requisição)
    # para evitar atrasos desnecessários
    next = generate_packet(type, ppf_time, ppf_size, reply.time)

    # noreply, porque ja respondemos antes
    {:noreply, {type, ppf_time, ppf_size, next}}
  end

  def handle_call({:delay, amount}, _from, {type, ppf_time, ppf_size, reply}) do
    # atrasamos a chegada do pacote
    next = Packet.delay_arrival(reply, amount)
    {:reply, :ok, {type, ppf_time, ppf_size, next}}
  end
end

defmodule VoiceGenerator do
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    {:ok, packet_gen} = PacketGenerator.start_link([
      type: :voice,
      ppf_time: Distributions.constant(16),
      ppf_size: Distributions.constant(512),
    ])
    ppf_delay = Statistics.Distributions.Exponential.ppf(1/650)

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
      type: :data,
      ppf_time: Statistics.Distributions.Exponential.ppf(1),
      ppf_size: Distributions.data_size(),
    ])
  end
end
