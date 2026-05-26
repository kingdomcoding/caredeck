%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/", "config/"],
        excluded: ["assets/", "priv/static/", "_build/", "deps/"]
      },
      strict: true,
      checks: %{
        enabled: [
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Readability.ModuleDoc, false},
          {Credo.Check.Refactor.LongQuoteBlocks, []}
        ],
        disabled: [
          {Credo.Check.Readability.PreferImplicitTry, []}
        ]
      }
    }
  ]
}
