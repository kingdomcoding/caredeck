defmodule Caredeck.Feed.Attachment do
  use Caredeck.Resource,
    domain: Caredeck.Feed,
    paper_trail: [attributes_as_attributes: [:facility_id]]

  postgres do
    table "attachments"
    repo Caredeck.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :facility_id
  end

  attributes do
    uuid_primary_key :id

    attribute :facility_id, :uuid, allow_nil?: false, public?: true
    attribute :post_id, :uuid, allow_nil?: false, public?: true

    attribute :kind, :atom,
      constraints: [one_of: [:photo, :video, :audio, :document]],
      allow_nil?: false,
      public?: true

    attribute :s3_key, :string, allow_nil?: false, public?: true
    attribute :thumbnail_s3_key, :string, public?: true
    attribute :mime_type, :string, public?: true
    attribute :bytes, :integer, public?: true
    attribute :duration_sec, :integer, public?: true
    attribute :caption, :string, public?: true
    attribute :position, :integer, default: 0, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :facility, Caredeck.Org.Facility, allow_nil?: false
    belongs_to :post, Caredeck.Feed.Post, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :facility_id,
        :post_id,
        :kind,
        :s3_key,
        :thumbnail_s3_key,
        :mime_type,
        :bytes,
        :duration_sec,
        :caption,
        :position
      ]

      change after_action(fn _changeset, attachment, _ctx ->
               if attachment.kind == :photo and
                    Application.get_env(:caredeck, :thumbnailer_mode, :async) == :async do
                 %{attachment_id: attachment.id, facility_id: attachment.facility_id}
                 |> Caredeck.Workers.Thumbnailer.new()
                 |> Oban.insert()
               end

               {:ok, attachment}
             end)
    end

    update :update do
      primary? true
      accept [:caption, :position, :thumbnail_s3_key]
    end

    action :request_upload_url, :map do
      argument :facility_id, :uuid, allow_nil?: false

      argument :kind, :atom,
        constraints: [one_of: [:photo, :video, :audio, :document]],
        allow_nil?: false

      argument :filename, :string, allow_nil?: false

      run fn input, _ctx ->
        kind_prefix = to_string(input.arguments.kind) <> "s"
        key = Caredeck.Feed.S3.generate_key(kind_prefix, input.arguments.filename)
        {:ok, url} = Caredeck.Feed.S3.presigned_put_url(key)
        {:ok, %{s3_key: key, upload_url: url, expires_in: 600}}
      end
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end
end
