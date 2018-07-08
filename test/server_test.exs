defmodule ServerTest do
  use ExUnit.Case, async: true

  test "create a server" do
    {:ok, server} = Server.initialize_server()
    assert Server.empty(server) === true
  end

  test "add a packet" do
    {:ok, server} = Server.initialize_server()
    Server.add_packet(server, 120, %Packet{time: 100,size: 100,from: 1})
    assert Server.empty(server) === false
  end

  test "remove a packet, adding the time spend on server to it" do
    {:ok, server} = Server.initialize_server()
    a = %Packet{time: 100, size: 100, from: 1}
    Server.add_packet(server, 100, a)

    assert Server.remove_packet(server, 140) === %Packet{
      time: 100, size: 100, from: 1, time_on_server: 40
    }
  end
    
end
