defmodule Caredeck.Feed.S3 do
  def bucket, do: Application.fetch_env!(:caredeck, :s3_bucket)

  def ensure_bucket! do
    case ExAws.S3.head_bucket(bucket()) |> ExAws.request() do
      {:ok, _} ->
        :ok

      {:error, _} ->
        {:ok, _} = ExAws.S3.put_bucket(bucket(), "us-east-1") |> ExAws.request()
        :ok
    end
  end

  def put_object(key, binary, content_type) do
    ExAws.S3.put_object(bucket(), key, binary, content_type: content_type)
    |> ExAws.request()
  end

  def get_object(key) do
    ExAws.S3.get_object(bucket(), key) |> ExAws.request()
  end

  def presigned_put_url(key, expires_in_seconds \\ 600) do
    config = ExAws.Config.new(:s3)
    ExAws.S3.presigned_url(config, :put, bucket(), key, expires_in: expires_in_seconds)
  end

  def generate_key(prefix, original_filename) do
    ext = original_filename |> Path.extname() |> String.downcase()
    "#{prefix}/#{Ecto.UUID.generate()}#{ext}"
  end
end
