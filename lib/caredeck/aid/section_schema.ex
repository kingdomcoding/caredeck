defmodule Caredeck.Aid.SectionSchema do
  alias Caredeck.Aid.MaritalStatus

  @sections [
    %{
      key: :welcome,
      label: "Welcome",
      sub_sections: [%{key: :intro, label: "Before you start"}],
      fields: []
    },
    %{
      key: :person_needing_care,
      label: "Person Needing Care",
      sub_sections: [
        %{key: :personal, label: "Personal details"},
        %{key: :address, label: "Address"}
      ],
      fields: [
        %{key: :first_name, label: "First name", kind: :string, sub: :personal, required: true},
        %{key: :last_name, label: "Last name", kind: :string, sub: :personal, required: true},
        %{key: :birth_name, label: "Birth name (if different)", kind: :string, sub: :personal},
        %{key: :date_of_birth, label: "Date of birth", kind: :date, sub: :personal, required: true},
        %{key: :birth_place, label: "Place of birth", kind: :string, sub: :personal},
        %{
          key: :marital_status,
          label: "Marital status",
          kind: {:enum, MaritalStatus},
          sub: :personal,
          required: true
        },
        %{key: :postal_code, label: "Postal code", kind: :string, sub: :address, required: true},
        %{key: :street, label: "Street + number", kind: :string, sub: :address, required: true},
        %{key: :city, label: "City", kind: :string, sub: :address, required: true}
      ]
    },
    %{
      key: :applicant,
      label: "Applicant",
      sub_sections: [%{key: :you, label: "Your details"}],
      fields: [
        %{key: :first_name, label: "Your first name", kind: :string, sub: :you, required: true},
        %{key: :last_name, label: "Your last name", kind: :string, sub: :you, required: true},
        %{
          key: :relationship,
          label: "Relationship to person needing care",
          kind: :string,
          sub: :you,
          required: true
        },
        %{key: :phone, label: "Phone number", kind: :string, sub: :you, required: true},
        %{key: :email, label: "Email", kind: :string, sub: :you, required: true}
      ]
    },
    %{
      key: :care_situation,
      label: "Care Situation",
      sub_sections: [
        %{key: :level, label: "Care level"},
        %{key: :setting, label: "Setting"}
      ],
      fields: [
        %{
          key: :care_level,
          label: "Assigned care level (1-5)",
          kind: :integer,
          sub: :level,
          required: true
        },
        %{
          key: :since_date,
          label: "Care level assigned since",
          kind: :date,
          sub: :level,
          required: true
        },
        %{
          key: :setting,
          label: "Current care setting",
          kind: {:enum, :care_setting},
          sub: :setting,
          required: true
        },
        %{key: :weekly_hours, label: "Care hours per week", kind: :integer, sub: :setting}
      ]
    },
    %{
      key: :income,
      label: "Income",
      sub_sections: [%{key: :monthly, label: "Monthly income"}],
      fields: [
        %{
          key: :pension_eur_month,
          label: "Pension (per month)",
          kind: :decimal,
          sub: :monthly,
          required: true
        },
        %{
          key: :rent_eur_month,
          label: "Rental income (per month)",
          kind: :decimal,
          sub: :monthly
        },
        %{
          key: :other_eur_month,
          label: "Other income (per month)",
          kind: :decimal,
          sub: :monthly
        }
      ]
    },
    %{key: :income_partner, label: "Income — Partner", sub_sections: [], fields: []},
    %{
      key: :assets,
      label: "Assets",
      sub_sections: [%{key: :accounts, label: "Bank accounts + savings"}],
      fields: [
        %{
          key: :savings_eur,
          label: "Savings total",
          kind: :decimal,
          sub: :accounts,
          required: true
        },
        %{
          key: :property_value_eur,
          label: "Property value",
          kind: :decimal,
          sub: :accounts
        }
      ]
    },
    %{key: :assets_partner, label: "Assets — Partner", sub_sections: [], fields: []},
    %{
      key: :gifts_given,
      label: "Gifts Given",
      sub_sections: [%{key: :recent, label: "Gifts in the last 10 years"}],
      fields: [
        %{
          key: :any_gifts_over_500,
          label: "Any gifts over €500 in the last 10 years?",
          kind: :boolean,
          sub: :recent,
          required: true
        },
        %{
          key: :gifts_description,
          label: "If yes, briefly describe",
          kind: :text,
          sub: :recent
        }
      ]
    },
    %{key: :gifts_given_partner, label: "Gifts Given — Partner", sub_sections: [], fields: []},
    %{
      key: :expenses,
      label: "Expenses",
      sub_sections: [%{key: :monthly, label: "Monthly expenses"}],
      fields: [
        %{key: :rent_eur_month, label: "Rent (per month)", kind: :decimal, sub: :monthly},
        %{
          key: :utilities_eur_month,
          label: "Utilities (per month)",
          kind: :decimal,
          sub: :monthly
        },
        %{
          key: :care_costs_eur_month,
          label: "Out-of-pocket care costs (per month)",
          kind: :decimal,
          sub: :monthly
        }
      ]
    },
    %{
      key: :disability,
      label: "Disability",
      sub_sections: [%{key: :status, label: "Status"}],
      fields: [
        %{
          key: :has_disability_status,
          label: "Recognised disability status?",
          kind: :boolean,
          sub: :status,
          required: true
        },
        %{key: :degree_percent, label: "Degree (%)", kind: :integer, sub: :status}
      ]
    },
    %{
      key: :foreign_nationality,
      label: "Foreign-Nationality Status",
      sub_sections: [%{key: :status, label: "Status"}],
      fields: [
        %{
          key: :nationality,
          label: "Nationality",
          kind: :string,
          sub: :status,
          required: true
        },
        %{key: :years_in_country, label: "Years in current country", kind: :integer, sub: :status}
      ]
    },
    %{
      key: :spouse,
      label: "Spouse",
      conditional: :marital_status_requires_spouse,
      sub_sections: [%{key: :details, label: "Spouse details"}],
      fields: [
        %{
          key: :first_name,
          label: "Spouse first name",
          kind: :string,
          sub: :details,
          required: true
        },
        %{
          key: :last_name,
          label: "Spouse last name",
          kind: :string,
          sub: :details,
          required: true
        },
        %{
          key: :date_of_birth,
          label: "Spouse date of birth",
          kind: :date,
          sub: :details,
          required: true
        }
      ]
    }
  ]

  def all, do: @sections
  def base, do: Enum.reject(@sections, &Map.get(&1, :conditional))

  def get(key), do: Enum.find(@sections, &(&1.key == key))
  def fields(key), do: get(key).fields
  def sub_sections(key), do: get(key).sub_sections

  def required_fields(key) do
    fields(key) |> Enum.filter(&Map.get(&1, :required)) |> Enum.map(& &1.key)
  end

  def complete?(key, answer_map) do
    required_fields(key) |> Enum.all?(&Map.has_key?(answer_map, &1))
  end

  def parse(:string, v) when is_binary(v), do: {:ok, v}
  def parse(:text, v) when is_binary(v), do: {:ok, v}
  def parse(:date, v) when is_binary(v), do: Date.from_iso8601(v)
  def parse(:integer, v) when is_binary(v), do: parse_int(v)

  def parse(:decimal, v) when is_binary(v) do
    case Decimal.parse(v) do
      {d, ""} -> {:ok, d}
      _ -> :error
    end
  end

  def parse(:boolean, v) when v in [true, "true", "on", "1"], do: {:ok, true}
  def parse(:boolean, v) when v in [false, "false", "off", "0", nil, ""], do: {:ok, false}

  def parse({:enum, _}, v) when is_binary(v) and v != "" do
    {:ok, String.to_existing_atom(v)}
  rescue
    ArgumentError -> :error
  end

  def parse(_kind, _v), do: :error

  def value_column(:string), do: :value_text
  def value_column(:text), do: :value_text
  def value_column(:date), do: :value_date
  def value_column(:integer), do: :value_decimal
  def value_column(:decimal), do: :value_decimal
  def value_column(:boolean), do: :value_bool
  def value_column({:enum, _}), do: :value_atom

  defp parse_int(v) do
    case Integer.parse(v) do
      {n, ""} -> {:ok, n}
      _ -> :error
    end
  end
end
