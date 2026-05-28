defmodule Caredeck.Kitchen do
  use Ash.Domain, otp_app: :caredeck

  resources do
    resource Caredeck.Kitchen.Product
    resource Caredeck.Kitchen.Product.Version
    resource Caredeck.Kitchen.MenuTemplate
    resource Caredeck.Kitchen.MenuTemplate.Version
    resource Caredeck.Kitchen.MenuTemplateSlot
    resource Caredeck.Kitchen.MenuTemplateSlot.Version
    resource Caredeck.Kitchen.DayMenu
    resource Caredeck.Kitchen.DayMenu.Version
    resource Caredeck.Kitchen.DayMenuSlot
    resource Caredeck.Kitchen.DayMenuSlot.Version
    resource Caredeck.Kitchen.ResidentDietProfile
    resource Caredeck.Kitchen.ResidentDietProfile.Version
    resource Caredeck.Kitchen.ResidentMealOrder
    resource Caredeck.Kitchen.ResidentMealOrder.Version
  end
end
