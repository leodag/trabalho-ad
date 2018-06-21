defmodule Distribuicoes do
  def init() do
    :rand.seed(:exs1024s, {123, 123534, 345345})
  end

  def uniforme() do
    :rand.uniform()
  end

  def exponencial(lambda) do
    Statistics.Distributions.Exponential.ppf(lambda)
  end
end
