defmodule Caredeck.Aid.SectionSchemaTest do
  use ExUnit.Case, async: true

  alias Caredeck.Aid.SectionSchema

  test "all/0 returns 14 sections (13 base + 1 conditional)" do
    assert length(SectionSchema.all()) == 14
  end

  test "base/0 returns the 13 non-conditional sections" do
    assert length(SectionSchema.base()) == 13
    refute Enum.any?(SectionSchema.base(), &Map.get(&1, :conditional))
  end

  describe "parse/2" do
    test "string" do
      assert SectionSchema.parse(:string, "hello") == {:ok, "hello"}
    end

    test "date" do
      assert SectionSchema.parse(:date, "2026-05-29") == {:ok, ~D[2026-05-29]}
      assert SectionSchema.parse(:date, "nope") == {:error, :invalid_format}
    end

    test "integer" do
      assert SectionSchema.parse(:integer, "42") == {:ok, 42}
      assert SectionSchema.parse(:integer, "abc") == :error
    end

    test "decimal" do
      {:ok, d} = SectionSchema.parse(:decimal, "1234.56")
      assert Decimal.equal?(d, Decimal.new("1234.56"))
    end

    test "boolean" do
      assert SectionSchema.parse(:boolean, "true") == {:ok, true}
      assert SectionSchema.parse(:boolean, "false") == {:ok, false}
      assert SectionSchema.parse(:boolean, "") == {:ok, false}
    end

    test "enum" do
      assert SectionSchema.parse({:enum, Caredeck.Aid.MaritalStatus}, "married") ==
               {:ok, :married}
    end
  end

  describe "value_column/1" do
    test "routes each kind to the right column" do
      assert SectionSchema.value_column(:string) == :value_text
      assert SectionSchema.value_column(:date) == :value_date
      assert SectionSchema.value_column(:integer) == :value_decimal
      assert SectionSchema.value_column(:decimal) == :value_decimal
      assert SectionSchema.value_column(:boolean) == :value_bool
      assert SectionSchema.value_column({:enum, Caredeck.Aid.MaritalStatus}) == :value_atom
    end
  end

  describe "required_fields/1 + complete?/2" do
    test "person_needing_care has required keys" do
      required = SectionSchema.required_fields(:person_needing_care)
      assert :first_name in required
      assert :last_name in required
      assert :marital_status in required
      refute :birth_name in required
    end

    test "complete?/2 is true only when all required keys are present" do
      refute SectionSchema.complete?(:person_needing_care, %{first_name: "A"})

      assert SectionSchema.complete?(:person_needing_care, %{
               first_name: "A",
               last_name: "B",
               date_of_birth: ~D[1940-01-01],
               marital_status: :widowed,
               postal_code: "12345",
               street: "1 Main",
               city: "Townsville"
             })
    end
  end
end
