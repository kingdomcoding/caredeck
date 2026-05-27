defmodule Caredeck.PolicyAuditTest do
  use ExUnit.Case, async: true

  @resources [
    Caredeck.Accounts.User,
    Caredeck.Accounts.TeamIdentity,
    Caredeck.Org.District,
    Caredeck.Org.Facility,
    Caredeck.Org.Ward,
    Caredeck.Org.FacilityMembership
  ]

  test "every protected resource declares a non-empty policies block" do
    for resource <- @resources do
      policies = Ash.Policy.Info.policies(resource)

      assert is_list(policies) and policies != [],
             "#{inspect(resource)} has no policies. Every resource must declare at least one."
    end
  end
end
