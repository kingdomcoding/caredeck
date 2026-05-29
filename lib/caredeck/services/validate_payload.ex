defmodule Caredeck.Services.ValidatePayload do
  use Ash.Resource.Change

  alias Caredeck.Services.{PayloadSchema, ServiceProvider}

  @impl true
  def change(changeset, _opts, _ctx) do
    provider_id = Ash.Changeset.get_attribute(changeset, :provider_id)
    payload = Ash.Changeset.get_attribute(changeset, :payload) || %{}
    tenant = changeset.tenant || Ash.Changeset.get_attribute(changeset, :facility_id)

    with {:ok, provider} <-
           Ash.get(ServiceProvider, provider_id, tenant: tenant, authorize?: false),
         {:ok, validated} <- safe_validate(provider.kind, payload) do
      Ash.Changeset.change_attribute(changeset, :payload, validated)
    else
      {:error, msg} ->
        Ash.Changeset.add_error(changeset, field: :payload, message: msg)

      _ ->
        Ash.Changeset.add_error(changeset, field: :provider_id, message: "provider not found")
    end
  end

  defp safe_validate(kind, payload) do
    {:ok, PayloadSchema.validate!(kind, payload)}
  rescue
    e in ArgumentError -> {:error, Exception.message(e)}
  end
end
