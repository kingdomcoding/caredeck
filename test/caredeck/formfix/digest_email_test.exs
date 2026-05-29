defmodule Caredeck.Formfix.DigestEmailTest do
  use ExUnit.Case, async: true

  alias Caredeck.Formfix.DigestEmail

  test "inline_pill_style/1 returns distinct hex pairs for each state" do
    states = [:draft, :missing_documents, :ready_to_submit, :submitted, :approved]

    styles = Enum.map(states, &DigestEmail.inline_pill_style/1)
    assert length(Enum.uniq(styles)) == 5

    assert DigestEmail.inline_pill_style(:draft) =~ "#fef3c7"
    assert DigestEmail.inline_pill_style(:missing_documents) =~ "#ffedd5"
    assert DigestEmail.inline_pill_style(:ready_to_submit) =~ "#dbeafe"
    assert DigestEmail.inline_pill_style(:submitted) =~ "#ede9fe"
    assert DigestEmail.inline_pill_style(:approved) =~ "#dcfce7"
  end

  test "status_label/1 returns title-cased English strings" do
    assert DigestEmail.status_label(:draft) == "Draft"
    assert DigestEmail.status_label(:missing_documents) == "Missing Documents"
    assert DigestEmail.status_label(:ready_to_submit) == "Ready to Submit"
    assert DigestEmail.status_label(:submitted) == "Submitted"
    assert DigestEmail.status_label(:approved) == "Approved"
  end

  test "admin_email/1 derives recipient from facility slug" do
    assert DigestEmail.admin_email(%{slug: "spring-hill"}) ==
             "admin+spring-hill@caredeck.example"
  end
end
