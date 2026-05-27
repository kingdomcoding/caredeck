defmodule Caredeck.Release.NamePool do
  @first_names ~w(
    Alice Bernard Carla Daniel Edith Frieda Greta Heinrich Ida Jakob
    Karl Liese Magnus Nora Otto Petra Rosa Stefan Theo Ursula
    Viktor Walter Anna Bruno Clara Dieter Elsa Fritz Gisela Hans
    Inge Johann Klaus Lotte Martha Nikolaus Olga Paul Renate Sophie
    Tobias Uwe Vera Werner Xenia Yvonne Zoe Adam Beatrice Charlotte
    Dominik Erika Felix Gertrud Hugo Irma Jens Katharina Lukas Maria
    Niklas Oskar Pia Quentin Ruth Stella Thomas Ulrich Vincent Wilma
  )

  @last_names ~w(
    Schmidt Müller Becker Wagner Fischer Weber Schulz Hoffmann Bauer Hartmann
    Meier Schäfer Koch Richter Klein Schwarz Wolf Zimmermann Braun Krüger
    Schneider Lange König Hofmann Kaiser Fuchs Lehmann Walter Krause Werner
    Schmitt Schreiber Gerber Vogel Stein Roth Berger Kruse Friedrich Otto
    Engel Heinrich Albrecht Lorenz Maier Reuter Voss Brandt Frank Hahn
  )

  def random_first_name, do: Enum.random(@first_names)
  def random_last_name, do: Enum.random(@last_names)

  def random_birth_date(min_age \\ 72, max_age \\ 96) do
    age = Enum.random(min_age..max_age)
    today = Date.utc_today()
    Date.add(today, -age * 365 - Enum.random(0..364))
  end
end
