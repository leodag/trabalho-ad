defmodule Arrival do
  @enforce_keys [:time]
  defstruct [:time, :Packet]
end

defmodule Departure do
  @enforce_keys [:time]
  defstruct [:time, :Packet]
end

defmodule Packet do
  @enforce_keys [:time, :size, :from]
  defstruct [
    :time,
    :size,
    :from,
    {:time_on_server, 0},
    {:time_on_queue, 0},
    :last_queue_arrival,
    {:last, false},
    {:generator_id, 0},
    :first_in_period
  ]
end

defmodule Components do
  @enforce_keys [:voice_source, :data_source, :voice_queue, :data_queue, :server, :preemptible]
  defstruct [:voice_source, :data_source, :voice_queue, :data_queue, :server, :preemptible]
end
