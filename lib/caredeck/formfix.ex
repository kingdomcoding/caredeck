defmodule Caredeck.Formfix do
  use Ash.Domain, otp_app: :caredeck

  resources do
    resource Caredeck.Formfix.Application
    resource Caredeck.Formfix.Application.Version
    resource Caredeck.Formfix.ApplicationSection
    resource Caredeck.Formfix.ApplicationSection.Version
    resource Caredeck.Formfix.SectionAnswer
    resource Caredeck.Formfix.SectionAnswer.Version
    resource Caredeck.Formfix.UploadedDocument
    resource Caredeck.Formfix.UploadedDocument.Version
  end
end
