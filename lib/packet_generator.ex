defmodule PacketGenerator do
  use GenServer

  # a estrutura que mantém o estado deste processo
  # ppf_time é a ppf dos intervalos de tempo entre os pacotes
  # ppf_size é a ppf do tamanho do pacote
  # reply é a próxima
  defstruct [:ppf_time, :ppf_size, :reply]

  # recebe duas ppf (inversa da cdf), uma para tamanho do pacote
  # e uma para incremento do tempo
  def start_link(opts, gs_opts \\ []) do
    GenServer.start_link(__MODULE__, opts, gs_opts)
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
    {:ok, %PacketGenerator{ppf_time: ppf_time, ppf_size: ppf_size, reply: reply}}
  end

  # gera um numero na distribuição especificada
  defp generate_number(ppf) do
    ppf.(:rand.uniform())
  end

  # gera uma chegada (um pacote)
  defp generate_packet(ppf_time, ppf_size, prev_time) do
    %Packet{
      time: prev_time + generate_number(ppf_time),
      size: generate_number(ppf_size),
      from: self()
    }
  end

  # retorna o próximo pacote
  def handle_call(:get_packet, from, state = %PacketGenerator{}) do
    GenServer.reply(from, state.reply)

    # calculamos depois de responder (e antes da próxima requisição)
    # para evitar atrasos desnecessários
    next = generate_packet(state.ppf_time, state.ppf_size, state.reply.time)

    # noreply, porque ja respondemos antes
    {:noreply, %{state | reply: next}}
  end

  # obtém o instante da chegada do próximo pacote
  def handle_call(:next_time, _from, state = %PacketGenerator{reply: next}) do
    {:reply, next.time, state}
  end

  # atrasa o próximo pacote
  def handle_call({:delay, amount}, _from, state = %PacketGenerator{}) do
    # atrasamos a chegada do pacote
    next = %Packet{state.reply | time: state.reply.time + amount}
    {:reply, :ok, %{state | reply: next}}
  end
end

# Gerador de voz: atua como um "proxy" na frente de um gerador de pacotes, e a cada
# pacote gerado avalia se deve iniciar um período de silêncio (gerando a distribuição
# geométrica do número N de pacotes
defmodule VoiceGenerator do
  use GenServer

  # estrutura do estado do gerador:
  # packet_gen: pid do gerador, que utilizamos para encaminhar os pedidos de pacotes
  # ppf_delay: ppf do período de silêncio
  # delay_chance: chance de iniciarmos um período de silêncio após um dado pacote
  # generator_id: identificador do gerador
  # first_in_period: instante do primeiro pacote após um período de silêncio
  defstruct [:packet_gen, :ppf_delay, :delay_chance, :generator_id, :first_in_period]

  # inicia o processo. Argumentos que podem ser passados no array opts:
  # generator_id: id do gerador de voz (geralmente, de 1 a 30)
  def start_link(opts, gs_opts \\ []) do
    GenServer.start_link(__MODULE__, opts, gs_opts)
  end

  def init(opts) do
    generator_id = Keyword.get(opts, :generator_id, 0)

    {:ok, packet_gen} =
      PacketGenerator.start_link(
        # 16 ms
        ppf_time: Distributions.constant(0.016),
        ppf_size: Distributions.constant(512)
      )

    # media: 650 ms
    ppf_delay = Statistics.Distributions.Exponential.ppf(1 / 0.650)

    # atraso inicial
    delay(packet_gen, ppf_delay)

    {
      :ok,
      %VoiceGenerator{
        packet_gen: packet_gen,
        generator_id: generator_id,
        first_in_period: PacketGenerator.next_time(packet_gen),
        ppf_delay: ppf_delay,
        delay_chance: 1 / 22
      }
    }
  end

  # gera um numero na distribuição especificada
  defp generate_number(ppf) do
    ppf.(:rand.uniform())
  end

  # atrasa o próximo pacote
  defp delay(packet_gen, ppf_delay) do
    # gera o tempo pelo qual o pacote será atrasado
    amount = generate_number(ppf_delay)
    PacketGenerator.delay(packet_gen, amount)
  end

  def handle_call(:get_packet, _from, state = %VoiceGenerator{}) do
    # substitui o campo from para o pid deste processo e identifica o gerador
    reply = %{
      PacketGenerator.get_packet(state.packet_gen)
      | from: self(),
        generator_id: state.generator_id,
        first_in_period: state.first_in_period
    }

    {reply, state} =
      if :rand.uniform() < state.delay_chance do
	# caso verdadeiro: vamos atrasar o pacote
        re = %{reply | last: true}
        delay(state.packet_gen, state.ppf_delay)
        {re, %{state | first_in_period: PacketGenerator.next_time(state.packet_gen)}}
      else
        {reply, state}
      end

    {:reply, reply, state}
  end

  def handle_call(:next_time, _from, state = %VoiceGenerator{}) do
    {:reply, PacketGenerator.next_time(state.packet_gen)}
  end
end

# instancia o PacketGenerator com os parâmetros do gerador de dados, para um dado rho
defmodule DataGenerator do
  def start_link(opts, gs_opts \\ []) do
    # default: rho = 10% de 2Mbps
    lambda = Keyword.get(opts, :lambda, 264.9)

    PacketGenerator.start_link(
      [
        ppf_time: Statistics.Distributions.Exponential.ppf(lambda),
        ppf_size: &Distributions.data_size_ppf/1
      ],
      gs_opts
    )
  end
end
