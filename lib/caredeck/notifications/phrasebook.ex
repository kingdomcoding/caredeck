defmodule Caredeck.Notifications.Phrasebook do
  def render(%{verb: :posted, actor: actor, target: target}),
    do: "#{actor} posted a new update about #{target}"

  def render(%{verb: :commented, actor: actor, target: target}),
    do: "#{actor} commented on a post about #{target}"

  def render(%{verb: :liked, actor: actor, target: target}),
    do: "#{actor} liked a post about #{target}"

  def render(%{verb: :joined, actor: actor, target: target}),
    do: "#{actor} joined the family for #{target}"

  def render(_), do: "Someone interacted with a post"
end
