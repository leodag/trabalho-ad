defmodule FilaEventosTest do
  use ExUnit.Case, async: true

  test "push a event" do
    {:ok, event_queue} = FilaEventos.initialize_queue([])
    assert FilaEventos.size(event_queue) === 0

    FilaEventos.push(event_queue, %Arrival{time: 20})
    assert FilaEventos.size(event_queue) === 1
    assert FilaEventos.head(event_queue) === %Arrival{time: 20}
  end

  test "pop a event" do
    {:ok, event_queue} = FilaEventos.initialize_queue([])

    FilaEventos.push(event_queue, %Arrival{time: 20})
    assert FilaEventos.pop(event_queue) === %Arrival{time: 20}
  end

  test "events are stored sorted by time" do
    {:ok, event_queue} = FilaEventos.initialize_queue([])

    FilaEventos.push(event_queue, %Arrival{time: 20})
    FilaEventos.push(event_queue, %Arrival{time: 10})
    FilaEventos.push(event_queue, %Arrival{time: 50})
    assert FilaEventos.pop(event_queue) === %Arrival{time: 10}
    assert FilaEventos.pop(event_queue) === %Arrival{time: 20}
    assert FilaEventos.pop(event_queue) === %Arrival{time: 50}
  end

end



