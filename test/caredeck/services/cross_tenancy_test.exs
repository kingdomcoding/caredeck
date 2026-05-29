defmodule Caredeck.Services.CrossTenancyTest do
  use Caredeck.DataCase, async: false

  alias Caredeck.{Org, People, Services}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "MT Services #{suffix}", slug: "mts-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    facility_a = create_facility(district, "A", "mts-a-#{suffix}")
    facility_b = create_facility(district, "B", "mts-b-#{suffix}")

    provider_a =
      Services.ServiceProvider
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility_a.id, kind: :pharmacy, name: "RX A"},
        tenant: facility_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility_a.id, authorize?: false)

    resident_a =
      People.Resident
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: facility_a.id, first_name: "X", last_name: "Y"},
        tenant: facility_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility_a.id, authorize?: false)

    request_a =
      Services.ServiceRequest
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility_a.id,
          provider_id: provider_a.id,
          resident_id: resident_a.id,
          subkind: "general_question",
          summary: "Hi",
          payload: %{"subkind" => "general_question", "question" => "hello"}
        },
        tenant: facility_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility_a.id, authorize?: false)

    message_a =
      Services.ServiceMessage
      |> Ash.Changeset.for_create(
        :create,
        %{
          facility_id: facility_a.id,
          service_request_id: request_a.id,
          body: "first reply"
        },
        tenant: facility_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: facility_a.id, authorize?: false)

    %{
      facility_a: facility_a,
      facility_b: facility_b,
      provider_a: provider_a,
      request_a: request_a,
      message_a: message_a
    }
  end

  defp create_facility(district, name, slug) do
    Org.Facility
    |> Ash.Changeset.for_create(
      :create,
      %{district_id: district.id, name: name, slug: slug},
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  test "ServiceProvider without tenant raises" do
    assert_raise Ash.Error.Invalid, fn ->
      Ash.read!(Services.ServiceProvider, authorize?: false)
    end
  end

  test "ServiceRequest without tenant raises" do
    assert_raise Ash.Error.Invalid, fn ->
      Ash.read!(Services.ServiceRequest, authorize?: false)
    end
  end

  test "ServiceMessage without tenant raises" do
    assert_raise Ash.Error.Invalid, fn ->
      Ash.read!(Services.ServiceMessage, authorize?: false)
    end
  end

  test "ServiceProvider cross-facility read returns 0 rows", ctx do
    rows = Services.ServiceProvider |> Ash.read!(tenant: ctx.facility_b.id, authorize?: false)
    refute Enum.any?(rows, &(&1.id == ctx.provider_a.id))
  end

  test "ServiceRequest cross-facility read returns 0 rows", ctx do
    rows = Services.ServiceRequest |> Ash.read!(tenant: ctx.facility_b.id, authorize?: false)
    refute Enum.any?(rows, &(&1.id == ctx.request_a.id))
  end

  test "ServiceMessage cross-facility read returns 0 rows", ctx do
    rows = Services.ServiceMessage |> Ash.read!(tenant: ctx.facility_b.id, authorize?: false)
    refute Enum.any?(rows, &(&1.id == ctx.message_a.id))
  end

  test "ServiceProvider one_per_kind_per_facility identity enforced", ctx do
    assert_raise Ash.Error.Invalid, fn ->
      Services.ServiceProvider
      |> Ash.Changeset.for_create(
        :create,
        %{facility_id: ctx.facility_a.id, kind: :pharmacy, name: "Dup"},
        tenant: ctx.facility_a.id,
        authorize?: false
      )
      |> Ash.create!(tenant: ctx.facility_a.id, authorize?: false)
    end
  end
end
