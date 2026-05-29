defmodule Caredeck.Workers.FormfixDigestDispatchTest do
  use Caredeck.DataCase, async: false
  use Oban.Testing, repo: Caredeck.Repo

  alias Caredeck.Org
  alias Caredeck.Workers.{FormfixDigest, FormfixDigestDispatch}

  setup do
    suffix = :erlang.unique_integer([:positive])

    district =
      Org.District
      |> Ash.Changeset.for_create(
        :create,
        %{name: "Dis #{suffix}", slug: "dis-#{suffix}"},
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    fac_a = create_facility(district, "Dis A", "dis-a-#{suffix}")
    fac_b = create_facility(district, "Dis B", "dis-b-#{suffix}")

    %{fac_a: fac_a, fac_b: fac_b}
  end

  test "enqueues one FormfixDigest job per facility", ctx do
    :ok = FormfixDigestDispatch.perform(%Oban.Job{})

    assert_enqueued worker: FormfixDigest, args: %{"facility_id" => ctx.fac_a.id}
    assert_enqueued worker: FormfixDigest, args: %{"facility_id" => ctx.fac_b.id}
  end

  defp create_facility(d, name, slug) do
    Org.Facility
    |> Ash.Changeset.for_create(
      :create,
      %{district_id: d.id, name: name, slug: slug},
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end
end
