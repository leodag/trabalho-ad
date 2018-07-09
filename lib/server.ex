defmodule Server do
  use Agent

  @transimission_velocity 2000000

  def initialize_server() do
    Agent.start_link(fn ->
      %{}
    end)
  end

  @doc """
  returns true if server is empty and false otherwise
  """
  def empty(server) do
    Agent.get(server, fn(map) -> 
      Map.get(map, :Packet) === :nil
    end)
  end

  @doc """
  adds the packet and returns the time it will take to serve it
  """
  def add_packet(server, time, %Packet{}=packet) do
    Agent.update(server, fn(_) -> 
      Map.new([{:Packet, packet}, {:arrival_time, time}])
    end)

    time_to_serve_packet(packet)
  end

  def remove_packet(server, now) do
    Agent.get_and_update(server, fn(map) -> 
      Map.get_and_update(map, :Packet, fn(packet) ->
        {update_packet(packet, now, Map.get(map, :arrival_time)), nil}
      end)
    end)
  end

  defp time_to_serve_packet(packet) do
    packet.size / @transimission_velocity
  end

  defp update_packet(packet, now, arrival_time) do
    Map.update(packet, :time_on_server, 0, fn(time_on_server) ->
      case time_on_server do
        nil ->
          (now - arrival_time)
        _ ->
          time_on_server + (now - arrival_time)
      end
    end)
  end
end
