defmodule Caredeck.Repo.Migrations.RenameAidToFormfix do
  use Ecto.Migration

  @table_renames [
    {"aid_applications", "formfix_applications"},
    {"aid_applications_versions", "formfix_applications_versions"},
    {"aid_application_sections", "formfix_application_sections"},
    {"aid_application_sections_versions", "formfix_application_sections_versions"},
    {"aid_section_answers", "formfix_section_answers"},
    {"aid_section_answers_versions", "formfix_section_answers_versions"},
    {"aid_uploaded_documents", "formfix_uploaded_documents"},
    {"aid_uploaded_documents_versions", "formfix_uploaded_documents_versions"}
  ]

  @index_renames [
    {"aid_application_sections_one_per_section_per_application_index",
     "formfix_application_sections_one_per_section_per_application_index"},
    {"aid_section_answers_one_answer_per_field_index",
     "formfix_section_answers_one_answer_per_field_index"},
    {"aid_uploaded_documents_no_duplicate_upload_index",
     "formfix_uploaded_documents_no_duplicate_upload_index"}
  ]

  def up do
    for {old, new} <- @table_renames do
      execute("ALTER TABLE IF EXISTS #{old} RENAME TO #{new}")
    end

    for {old, new} <- @index_renames do
      execute("ALTER INDEX IF EXISTS #{old} RENAME TO #{new}")
    end
  end

  def down do
    for {old, new} <- @index_renames do
      execute("ALTER INDEX IF EXISTS #{new} RENAME TO #{old}")
    end

    for {old, new} <- @table_renames do
      execute("ALTER TABLE IF EXISTS #{new} RENAME TO #{old}")
    end
  end
end
