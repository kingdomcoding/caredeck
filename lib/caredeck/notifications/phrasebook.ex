defmodule Caredeck.Notifications.Phrasebook do
  def render(%{verb: :posted, actor: actor, target: target}),
    do: "#{actor} posted a new update about #{target}"

  def render(%{verb: :commented, actor: actor, target: target}),
    do: "#{actor} commented on a post about #{target}"

  def render(%{verb: :liked, actor: actor, target: target}),
    do: "#{actor} liked a post about #{target}"

  def render(%{verb: :joined, actor: actor, target: target}),
    do: "#{actor} joined the family for #{target}"

  def render(%{verb: :requested, actor: actor}),
    do: "#{actor} opened a service request"

  def render(%{verb: :replied, actor: actor}),
    do: "#{actor} replied on a service request"

  def render(_), do: "Someone interacted with a post"
end
