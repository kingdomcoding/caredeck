defmodule Caredeck.Services.PayloadSchemaTest do
  use ExUnit.Case, async: true

  alias Caredeck.Services.PayloadSchema

  @uuid "11111111-1111-1111-1111-111111111111"

  describe "pharmacy + prescription_upload" do
    test "accepts attachment_id + instructions" do
      p =
        PayloadSchema.validate!(:pharmacy, %{
          "subkind" => "prescription_upload",
          "attachment_id" => @uuid,
          "instructions" => "Take with food"
        })

      assert p["attachment_id"] == @uuid
      assert p["instructions"] == "Take with food"
    end

    test "defaults instructions to empty string when omitted" do
      p =
        PayloadSchema.validate!(:pharmacy, %{
          "subkind" => "prescription_upload",
          "attachment_id" => @uuid
        })

      assert p["instructions"] == ""
    end

    test "raises without an attachment_id" do
      assert_raise ArgumentError, fn ->
        PayloadSchema.validate!(:pharmacy, %{"subkind" => "prescription_upload"})
      end
    end
  end

  describe "pharmacy + medication_inquiry" do
    test "accepts medication_name + question" do
      p =
        PayloadSchema.validate!(:pharmacy, %{
          "subkind" => "medication_inquiry",
          "medication_name" => "Aspirin",
          "question" => "split?"
        })

      assert p["medication_name"] == "Aspirin"
    end

    test "raises without medication_name" do
      assert_raise ArgumentError, fn ->
        PayloadSchema.validate!(:pharmacy, %{
          "subkind" => "medication_inquiry",
          "question" => "split?"
        })
      end
    end
  end

  describe "laundry + complaint" do
    test "accepts the full bundle" do
      p =
        PayloadSchema.validate!(:laundry, %{
          "subkind" => "complaint",
          "service" => "Resident laundry",
          "reason" => "Item not properly processed",
          "details" => "Shirt collar still stained.",
          "attachment_id" => @uuid
        })

      assert p["reason"] == "Item not properly processed"
    end

    test "raises without attachment_id" do
      assert_raise ArgumentError, fn ->
        PayloadSchema.validate!(:laundry, %{
          "subkind" => "complaint",
          "service" => "Resident laundry",
          "reason" => "Lost",
          "details" => "Missing"
        })
      end
    end
  end

  describe "hairdresser + appointment_request" do
    test "accepts haircut_type and normalises post_to_feed" do
      p =
        PayloadSchema.validate!(:hairdresser, %{
          "subkind" => "appointment_request",
          "haircut_type" => "trim",
          "post_to_feed" => "true"
        })

      assert p["post_to_feed"] == true
      assert p["notes"] == ""
    end

    test "defaults post_to_feed to false when omitted" do
      p =
        PayloadSchema.validate!(:hairdresser, %{
          "subkind" => "appointment_request",
          "haircut_type" => "trim"
        })

      assert p["post_to_feed"] == false
    end

    test "raises without haircut_type" do
      assert_raise ArgumentError, fn ->
        PayloadSchema.validate!(:hairdresser, %{
          "subkind" => "appointment_request"
        })
      end
    end
  end

  test "raises on unknown kind/subkind" do
    assert_raise ArgumentError, fn ->
      PayloadSchema.validate!(:pharmacy, %{"subkind" => "what"})
    end
  end
end
