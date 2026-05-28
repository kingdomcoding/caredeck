defmodule Caredeck.Kitchen.MealCategory do
  @categories ~w(breakfast lunch dinner drinks fruit snack)a

  def all, do: @categories

  def labels do
    %{
      breakfast: "Breakfast",
      lunch: "Lunch",
      dinner: "Dinner",
      drinks: "Drinks",
      fruit: "Fruit",
      snack: "Snack"
    }
  end

  def label(c), do: Map.fetch!(labels(), c)
end
