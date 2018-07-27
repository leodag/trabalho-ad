# Fila de pacotes
defmodule Queue do
  use Agent

  # Inicializa o processo, com a fila vazia
  def start_link(_opts, gs_opts \\ []) do
    Agent.start_link(&:queue.new/0, gs_opts)
  end

  # Coloca um pacote no fim da fila
  def put(queue, item = %Packet{}) do
    Agent.update(queue, &put_and_set_arrival(&1, item))
  end

  # Retorna um pacote ao começo da fila
  def put_r(queue, item = %Packet{}, time) do
    Agent.update(queue, &put_r_and_update_arrival(&1, item, time))
  end

  # Obtém o primeiro pacote da fila (removendo-o dela)
  def get(queue, time) do
    Agent.get_and_update(queue, &get_and_update_time(&1, time))
  end

  # Obtém o instante no qual o primeiro pacote da fila foi gerado
  # (também é o instante no qual o pacote gostaria de começar a ser
  # servido - que seria não ter que esperar na fila)
  def next_time(queue) do
    Agent.get(queue, &get_next_time(&1))
  end

  # Obtém o comprimento da fila
  def len(queue) do
    Agent.get(queue, &:queue.len(&1))
  end

  # Obtém o tempo do próximo pacote da fila (:empty se estiver vazia)
  defp get_next_time(queue) do
    head = :queue.peek(queue)

    case head do
      {:value, %Packet{time: time}} ->
        time

      # :empty
      _ ->
        head
    end
  end

  # Coloca um pacote no final da fila, inicializando o tempo da entrada chegada na fila
  # do pacote (é utilizado para calcular o tempo gasto na fila)
  defp put_and_set_arrival(queue, item) do
    item = %{item | last_queue_arrival: item.time}
    :queue.in(item, queue)
  end

  # Coloca um pacote no começo da fila, atualizando o tempo da última chegada na fila
  defp put_r_and_update_arrival(queue, item, time) do
    item = %{item | last_queue_arrival: time}
    :queue.in_r(item, queue)
  end

  # Obtém o primeiro pacote da fila, com o tempo gasto na fila devidamente atualizado
  defp get_and_update_time(queue, time) do
    case :queue.out(queue) do
      {{:value, packet}, new_queue} ->
        {{:value,
          %{packet | time_on_queue: packet.time_on_queue + time - packet.last_queue_arrival}},
         new_queue}

      other ->
        other
    end
  end
end
