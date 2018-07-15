defmodule DataMaestroTest do
  use ExUnit.Case, async: true

  @packet %Packet{
      first_in_period: nil,
      from: 123,
      generator_id: 0,
      last: false,
      last_queue_arrival: 1.5513849683282828,
      size: 1471,
      time: 1.5513849683282828,
      time_on_queue: 0.0014231815257332858,
      time_on_server: 7.355e-4
  }

  @voice_producers 30
  test "criar o maestro de dados" do
    {:ok, _} = GenServer.start_link(DataMaestro, 0)
  end

  setup do
    {:ok, pid} = GenServer.start_link(DataMaestro, 0)

    {:ok, pid: pid}
  end

  test "array with correct size", %{pid: pid} do
    assert GenServer.call(pid, :size) === @voice_producers
  end

  test "media da fila de voz", %{pid: pid} do
    GenServer.cast(pid, {
      :data_arrival, #tipo de evento
      @packet,    #pacote
      4,            #numero de pacotes na fila de voz
      0,            #numero de pacotes na fila de dados
      1             #tempo no sistema
    })
    GenServer.cast(pid, {:voice_arrival, 0, 1, 0, 2})

    ret = GenServer.call(pid, :voice_stats)
    assert ret.mean_number === 2.5
  end

  test "media da fila de dados", %{pid: pid} do
    GenServer.cast(pid, {
      :data_arrival, #tipo de evento
      @packet,    #pacote
      0,            #numero de pacotes na fila de voz
      2,            #numero de pacotes na fila de dados
      1             #tempo no sistema
    })
    GenServer.cast(pid, {:data_arrival, 0, 0, 1, 2})


    ret = GenServer.call(pid, :data_stats)
    assert ret.mean_number === 1.5
  end
end
