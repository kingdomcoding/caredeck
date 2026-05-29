defmodule Caredeck.Services.PayloadSchema do
  @moduledoc false

  def validate!(:pharmacy, %{"subkind" => "prescription_upload"} = p) do
    require_uuid!(p, "attachment_id")
    Map.put_new(p, "instructions", "")
  end

  def validate!(:pharmacy, %{"subkind" => "medication_inquiry"} = p) do
    require_strings!(p, ~w(medication_name question))
    p
  end

  def validate!(:pharmacy, %{"subkind" => "general_question"} = p) do
    require_strings!(p, ~w(question))
    p
  end

  def validate!(:laundry, %{"subkind" => "complaint"} = p) do
    require_strings!(p, ~w(service reason details))
    require_uuid!(p, "attachment_id")
    p
  end

  def validate!(:hairdresser, %{"subkind" => "appointment_request"} = p) do
    require_strings!(p, ~w(haircut_type))

    p
    |> Map.put_new("notes", "")
    |> Map.put_new("post_to_feed", false)
    |> Map.update!("post_to_feed", &truthy?/1)
  end

  def validate!(:doctor, %{"subkind" => "appointment_request"} = p) do
    require_strings!(p, ~w(details))
    Map.put_new(p, "preferred_date", "")
  end

  def validate!(:doctor, %{"subkind" => "information_request"} = p) do
    require_strings!(p, ~w(details))
    p
  end

  def validate!(:podiatry, %{"subkind" => "appointment_request"} = p),
    do: validate!(:doctor, %{"subkind" => "appointment_request"} |> Map.merge(p))

  def validate!(:physio, %{"subkind" => "appointment_request"} = p),
    do: validate!(:doctor, %{"subkind" => "appointment_request"} |> Map.merge(p))

  def validate!(:florist, %{"subkind" => "order"} = p) do
    require_strings!(p, ~w(occasion))
    p
  end

  def validate!(kind, payload) do
    raise ArgumentError,
          "unrecognised service payload for #{inspect(kind)}: #{inspect(payload)}"
  end

  defp require_strings!(map, keys) do
    Enum.each(keys, fn k ->
      v = Map.get(map, k)

      unless is_binary(v) and v != "" do
        raise ArgumentError, "missing or blank string field `#{k}`"
      end
    end)
  end

  defp require_uuid!(map, key) do
    case Ecto.UUID.cast(Map.get(map, key)) do
      {:ok, _} -> :ok
      _ -> raise ArgumentError, "missing or invalid uuid field `#{key}`"
    end
  end

  defp truthy?(v) when v in [true, "true", "on", 1, "1"], do: true
  defp truthy?(_), do: false
end
