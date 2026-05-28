ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Caredeck.Repo, :manual)

case ExAws.S3.put_bucket(Caredeck.Feed.S3.bucket(), "us-east-1") |> ExAws.request() do
  {:ok, _} -> :ok
  {:error, {:http_error, 409, _}} -> :ok
  other -> IO.warn("test bucket setup: #{inspect(other)}")
end
