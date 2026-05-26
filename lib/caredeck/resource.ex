defmodule Caredeck.Resource do
  defmacro __using__(opts) do
    paper_trail_opts = Keyword.get(opts, :paper_trail, [])

    quote do
      use Ash.Resource,
        otp_app: :caredeck,
        data_layer: AshPostgres.DataLayer,
        notifiers: [Ash.Notifier.PubSub],
        authorizers: [Ash.Policy.Authorizer],
        extensions: [AshPaperTrail.Resource, AshArchival.Resource]

      paper_trail do
        change_tracking_mode(:changes_only)
        store_action_name?(true)
        ignore_attributes([:hashed_password])
        unquote(paper_trail_opts)
      end

      archive do
        attribute(:archived_at)
        base_filter?(false)
        exclude_read_actions([:get_with_archived, :list_with_archived])
      end

      pub_sub do
        module(CaredeckWeb.Endpoint)
        prefix("resource")
      end
    end
  end
end
