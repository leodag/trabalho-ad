defmodule PacketGenerator do
  # recebe duas ppf (inversa da cdf), uma para tamanho do pacote
  # e uma para incremento do tempo
  def start_link(opts) do
    ppf_time = Keyword.get(opts, :ppf_time, Distributions.constant(1))
    ppf_size = Keyword.get(opts, :ppf_size, Distributions.constant(1))

    # calculamos a chegada inicial
    reply = generate_packet(ppf_time, ppf_size, 0)
    Task.start_link(fn -> loop(ppf_time, ppf_size, reply) end)
  end

  def get_packet(pid) do
    send pid, {:request, self()}
    receive do
      {:reply, packet} -> packet
    end
  end

  def delay(pid, amount) do
    send pid, {:delay, amount}
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

  # loop principal
  defp loop(ppf_time, ppf_size, reply) do
    receive do
      # esperamos um request, e prontamente respondemos com o valor
      # previamente calculado
      {:request, caller} ->
    send caller, {:reply, reply}

    # calculamos depois de responder (e antes da próxima requisição)
    # para evitar atrasos desnecessários
    next = generate_packet(ppf_time, ppf_size, reply.time)
    loop(ppf_time, ppf_size, next)

      {:delay, delay} ->
    # atrasamos a chegada do pacote
    next = %Packet{reply | time: reply.time + delay}
    loop(ppf_time, ppf_size, next)
    end
  end
end


defmodule VoiceGenerator do
  def start_link(_opts) do
    {:ok, pid} = PacketGenerator.start_link([
      ppf_time: Distributions.constant(16_000),
      ppf_size: Distributions.constant(512),
    ])
    ppf_delay = Statistics.Distributions.Exponential.ppf(1/650_000)

    Task.start_link(fn -> loop(pid, ppf_delay, 1/22) end)
  end

  # gera um numero na distribuição especificada
  defp generate_number(ppf) do
    ppf.(:rand.uniform())
  end

  defp delay(pid, ppf_delay) do
    amount = generate_number(ppf_delay)
    PacketGenerator.delay(pid, amount)
  end

  defp loop(pid, ppf_delay, delay_chance) do
    receive do
      {:request, caller} ->
    send pid, {:request, caller}
    end

    if :rand.uniform() < delay_chance do
      delay(pid, ppf_delay)
    end

    loop(pid, ppf_delay, delay_chance)
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
