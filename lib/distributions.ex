defmodule Distributions do
  def constant(k) do
    fn _ -> k end
  end

  def data_size_cdf(s) when s >= 0 and s <= 64 do
    0
  end

  def data_size_cdf(s) when s >= 0 and s < 512 do
    0.3 + 0.3 / 1436 * (s - 64)
  end

  def data_size_cdf(s) when s >= 0 and s < 1500 do
    0.4 + 0.3 / 1436 * (s - 64)
  end

  def data_size_cdf(s) when s == 1500 do
    1
  end

  def data_size_ppf(s) when s >= 0 and s < 0.3 do
    64 * 8
  end

  # valor de s calculado utilizando data_size_cdf(512) - 0.1
  def data_size_ppf(s) when s >= 0 and s < 0.39359331476323123 do
    round((64 + 1436 / 0.3 * (s - 0.3)) * 8)
  end

  # valor de s calculado utilizando data_size_cdf(512)
  def data_size_ppf(s) when s >= 0 and s < 0.4935933147632312 do
    512 * 8
  end

  def data_size_ppf(s) when s >= 0 and s < 0.7 do
    # valor de s calculado utilizando data_size_cdf(512)
    round((512 + 1436 / 0.3 * (s - 0.4935933147632312)) * 8)
  end

  def data_size_ppf(s) when s >= 0 and s <= 1 do
    1500 * 8
  end

  def data_size() do
    &data_size_ppf/1
  end

  # por falta de umplementações eficientes do percentil da
  # distribuição t-student, implementamos esta versão para o
  # percentil de 95% com valores do site
  # https://keisan.casio.com/exec/system/1180573204
  def t_student(n, percentile = 0.95) when n > 0 do
    case n do
      1 -> 6.313751514675043098979
      2 -> 2.919985580353725686961
      3 -> 2.353363434801823877671
      4 -> 2.131846786326650318347
      5 -> 2.015048373333024237841
      6 -> 1.943180280515303206606
      7 -> 1.894578605090007389472
      8 -> 1.859548037530898390007
      9 -> 1.833112932656237168686
      10 -> 1.812461122811676413626
      11 -> 1.795884818704044100921
      12 -> 1.782287555649320074526
      13 -> 1.77093339598687292416
      14 -> 1.761310135774892090558
      15 -> 1.753050355692573507661
      16 -> 1.745883676276249927718
      17 -> 1.739606726075073032904
      18 -> 1.734063606617538753638
      19 -> 1.729132811521369520225
      20 -> 1.724718242920787272832
      21 -> 1.720742902811878533745
      22 -> 1.717144374380242804893
      23 -> 1.713871527747048076911
      24 -> 1.710882079909428441935
      25 -> 1.70814076125189927112
      26 -> 1.705617919759273233604
      27 -> 1.703288445722127083291
      28 -> 1.701130934265931628328
      29 -> 1.699127026533497750631
      # N >= 30: utilizamos a normal
      _ -> Statistics.Distrubutions.Normal.ppf().(percentile)
    end
  end
end
