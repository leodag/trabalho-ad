# TrabalhoAD

**TODO: Add description**

## Estrutura de um Evento

Pelo que consigo ver, só precisaremos ter dois tipos de eventos,todo o
envento precisa ter seu proprio tempo para a priorização na fila de 
eventos e para o calculo das estatísticas.

O `time` é o momento que o evento ocorre.



**TODO: Para o tempo vamos usar inteiros ou floats? Não entendo bem o bastante
de elixir para tomar essa decisão =)**

1. **Chegadas**

```elixir
%Arrival{
  type: (voice|data),
  size: (64bytes for voice| L for data),
  producer: (1...30 for voice| 0 for data),
  number_in_sequence: (1...N for voice| 1 for data),
  total_sequence: (N for voice| 1 for data),
  time: (int or float?)
}
```

Esse evento ira gerar ou um serviço(e por consequencia uma partida) se 
a fila estiver vazia ou ele tiver maior prioridade, ou entrará na fila 
de voz ou dados.

O `number_in_sequence` se refere a qual pacote do periodo ativo de um 
produtor voz essa chegada representa, sendo que o `total_sequece` representa
quantos pacotes ao total esse periodo ativo conterá.

`L` é o tamanho dado por essa formula:

![formula de L](https://i.gyazo.com/4750648b9e5daeef32c6e416899ba577.png)

`N` é o numero de pacotes gerado por uma geometrica com media 22.

![formula de N](https://i.gyazo.com/18841a6a73718e60a6ca3258a1e4faa8.png)


2. **Partidas**
 
```
%Departure{
  type: (voice|data),
  time_on_queue: (int or float?),
  time_on_server: Array of (int or float),
  producer: (1...30 for voice| 0 for data),
  number_in_sequence: (1...N for voice| 1 for data),
  total_sequence: (N for voice| 1 for data),
  time: (int or float?)
}
```

## Estrutra de Dados usada para Fila de Eventos

Vi que o Leonardo adicionou aqui uma dependencia de uma Priority Queue, mas dando
uma olhada nela me pareceu bem restritiva. Podemos usar a library 
[Heap](https://hexdocs.pm/heap/Heap.html#summary) e usar a MinHeap nela,
especificando o comparador que lide bem com nossas Structs de Eventos.

então podemos criar um Heap que priorize pelo `time` assim.

```java
# Struct de Arrival
iex(2)> defmodule Arrival do
...(2)>   defstruct [:time]
...(2)> end

# Struct de Departure
iex(3)> defmodule Departure do
...(3)>   defstruct [:time]
...(3)> end


iex(4)> (heap = Heap.new(&(&1.time < &2.time))
...(4)>   |> Heap.push(%Arrival{time: 20})
...(4)>   |> Heap.push(%Arrival{time: 10})
...(4)>   |> Heap.push(%Arrival{time: 30})
...(4)>   |> Heap.push(%Departure{time: 11})
...(4)>   |> Heap.push(%Departure{time: 1})
...(4)>   |> Heap.push(%Departure{time: 35}))
#Heap<[
  %Departure{time: 1},
  %Arrival{time: 10},
  %Departure{time: 11},
  %Arrival{time: 20},
  %Arrival{time: 30},
  %Departure{time: 35}
]>

```

**O que acham?**


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `trabalho_ad` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:trabalho_ad, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/trabalho_ad](https://hexdocs.pm/trabalho_ad).
