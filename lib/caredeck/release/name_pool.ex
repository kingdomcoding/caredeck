defmodule Caredeck.Release.NamePool do
  @first_names ~w(
    Alice Beatrice Charles Dorothy Edward Florence George Harriet Isaac James
    Kathleen Lawrence Margaret Nicholas Olivia Patrick Queenie Robert Susan Thomas
    Ursula Victor William Yvonne Zachary Albert Bernice Clifford Doris Ernest
    Frances Gerald Hannah Irene John Katherine Leonard Mabel Norman Phyllis
    Quentin Ralph Sylvia Terence Vera Wallace Constance Henry Joan Lillian
    Martin Nora Oliver Pauline Reginald Shirley Theodore Victoria Walter Audrey
    Bruce Caroline Dennis Eleanor Frank Geraldine Howard Iris Julian Lydia
    Marcus Nadine Owen Penelope
  )

  @last_names ~w(
    Smith Johnson Williams Brown Jones Miller Davis Wilson Anderson Taylor
    Thomas Moore Jackson Martin Lee Walker Hall Allen Young King Wright
    Scott Green Adams Baker Carter Mitchell Roberts Turner Phillips Campbell
    Parker Evans Edwards Collins Stewart Morris Murphy Cook Rogers Morgan
    Bell Bailey Cooper Richardson Howard Ward Cox Gray Watson Brooks Foster
  )

  def random_first_name, do: Enum.random(@first_names)
  def random_last_name, do: Enum.random(@last_names)

  def random_birth_date(min_age \\ 72, max_age \\ 96) do
    age = Enum.random(min_age..max_age)
    today = Date.utc_today()
    Date.add(today, -age * 365 - Enum.random(0..364))
  end
end
