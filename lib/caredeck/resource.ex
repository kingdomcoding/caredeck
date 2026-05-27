defmodule Caredeck.Resource do
  defmacro __using__(opts) do
    domain = Keyword.get(opts, :domain)
    paper_trail_opts = Keyword.get(opts, :paper_trail, [])
    paper_trail_attrs = Keyword.get(paper_trail_opts, :attributes_as_attributes, [])
    extra_extensions = Keyword.get(opts, :extensions, [])
    extensions = [AshPaperTrail.Resource, AshArchival.Resource] ++ extra_extensions

    quote do
      use Ash.Resource,
        otp_app: :caredeck,
        domain: unquote(domain),
        data_layer: AshPostgres.DataLayer,
        notifiers: [Ash.Notifier.PubSub],
        authorizers: [Ash.Policy.Authorizer],
        extensions: unquote(extensions)

      paper_trail do
        change_tracking_mode(:changes_only)
        store_action_name?(true)
        ignore_attributes([:hashed_password])
        attributes_as_attributes(unquote(paper_trail_attrs))
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
