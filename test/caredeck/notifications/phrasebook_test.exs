defmodule Caredeck.Notifications.PhrasebookTest do
  use ExUnit.Case, async: true

  alias Caredeck.Notifications.Phrasebook

  test "renders each known verb" do
    base = %{actor: "Anna", target: "Hilde"}

    assert Phrasebook.render(Map.put(base, :verb, :posted)) =~ "posted a new update"
    assert Phrasebook.render(Map.put(base, :verb, :commented)) =~ "commented on a post"
    assert Phrasebook.render(Map.put(base, :verb, :liked)) =~ "liked a post"
    assert Phrasebook.render(Map.put(base, :verb, :joined)) =~ "joined the family"
  end

  test "falls back to a friendly degraded sentence when verb is unknown" do
    assert Phrasebook.render(%{verb: :exploded, actor: "?", target: "?"}) ==
             "Someone interacted with a post"
  end

  test "handles unexpected input shape" do
    assert Phrasebook.render(nil) == "Someone interacted with a post"
    assert Phrasebook.render(%{}) == "Someone interacted with a post"
  end
end
