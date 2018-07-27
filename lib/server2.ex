defmodule Server2 do
  use GenServer

  ##
  ## API externa
  ##

  def start_link(opts, gs_opts \\ []) do
    GenServer.start_link(__MODULE__, opts, gs_opts)
  end

  def begin_serve(server, serve_start, type, packet) do
    GenServer.call(server, {:begin_serve, serve_start, type, packet})
  end

  def interrupt_serve(server, time) do
    GenServer.call(server, {:interrupt_serve, time})
  end

  def end_serve(server) do
    GenServer.call(server, :end_serve)
  end

  def status(server) do
    GenServer.call(server, :status)
  end

  # inicializa o servidor, no estado :empty
  def init(opts) do
    # 2 Mbps
    bandwidth = Keyword.get(opts, :bandwidth, 2_000_000)
    {:ok, {bandwidth, :empty}}
  end

  ##
  ## Callbacks do servidor
  ##

  # inicia um serviço: mantém o pacote no estado interno até algo causar o fim do seu serviço
  # (seja uma interrupção ou a partida do pacote)
  def handle_call({:begin_serve, time, type, packet = %Packet{}}, _from, {bandwidth, :empty}) do
    serve_end = time + packet.size / bandwidth

    {
      :reply,
      :ok,
      {bandwidth, {:serving, time, serve_end, type, packet}}
    }
  end

  # interrompe um serviço: só funciona caso haja algo em serviço (verificado pela assinatura da função).
  # retorna o pacote com o tempo gasto no servidor incrementado até o instante da interrupção.
  def handle_call(
        {:interrupt_serve, time},
        _from,
        {bandwidth, {:serving, serve_start, _serve_end, _type, packet}}
      ) do
    {
      :reply,
      add_serve_time(packet, serve_start, time),
      {bandwidth, :empty}
    }
  end

  # finaliza um serviço: retorna o pacote com o tempo gasto no servidor incrementado.
  def handle_call(
        :end_serve,
        _from,
        {bandwidth, {:serving, serve_start, serve_end, _type, packet}}
      ) do
    {
      :reply,
      add_serve_time(packet, serve_start, serve_end),
      {bandwidth, :empty}
    }
  end

  # obtém o status quando o servidor está ocioso: retorna :empty
  def handle_call(:status, _from, state = {_bandwidth, :empty}) do
    {:reply, :empty, state}
  end

  # obtém o status quando o servidor está ocupado: retorna o tempo que a partida ocorrerá caso
  # não haja interrupção e o tipo do pacote.
  def handle_call(
        :status,
        _from,
        state = {_bandwidth, {:serving, _serve_start, serve_end, type, _packet}}
      ) do
    {:reply, {:serving, serve_end, type}, state}
  end

  # função auxiliar privada (só pode ser utilizada neste módulo) que incrementa o tempo
  # em serviço do pacote até o instante 'time'
  defp add_serve_time(packet, serve_start, time) do
    %{packet | time_on_server: packet.time_on_server + time - serve_start}
  end
end
