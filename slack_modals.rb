
class NewIncidentModal
  def self.modal_json(trigger_id, initial_user_id=nil)
    {
      "trigger_id" => trigger_id,
      "view" => {
        "type" => "modal",
        "callback_id" => "incident_submission",
        "title" => {
          "type" => "plain_text",
          "text" => "Create Incident"
        },
        "blocks" => [
          {
            "type" => "input",
            "block_id" => "incident_name",
            "element" => {
              "type" => "plain_text_input",
              "action_id" => "incident_name_input"
            },
            "label" => {
              "type" => "plain_text",
              "text" => "Incident Name"
            }
          },
          {
            "type" => "input",
            "optional" => true,
            "block_id" => "incident_description",
            "element" => {
              "type" => "plain_text_input",
              "action_id" => "incident_description_input",
              "multiline" => true
            },
            "label" => {
              "type" => "plain_text",
              "text" => "Description"
            }
          },
          {
            "type" => "input",
            "optional" => true,
            "block_id" => "incident_priority",
            "element" => {
              "type" => "static_select",
              "action_id" => "incident_priority_input",
              "placeholder" => {
                "type" => "plain_text",
                "text" => "Leave blank if impact is unknown"
              },
              "options" =>  [
                {
                  "text" =>  {
                    "type" =>  "plain_text",
                    "text" =>  "P1 (Highest)"
                  },
                  "value" =>  "P1"
                },
                {
                  "text" =>  {
                    "type" =>  "plain_text",
                    "text" =>  "P2"
                  },
                  "value" =>  "P2"
                },
                {
                  "text" =>  {
                    "type" =>  "plain_text",
                    "text" =>  "P3"
                  },
                  "value" =>  "P3"
                },
                {
                  "text" =>  {
                    "type" =>  "plain_text",
                    "text" =>  "P4"
                  },
                  "value" =>  "P4"
                },
                {
                  "text" =>  {
                    "type" =>  "plain_text",
                    "text" =>  "P5 (Lowest)"
                  },
                  "value" =>  "P5"
                }
              ]
            },
            "label" => {
              "type" => "plain_text",
              "text" => "Incident Priority"
            }
          },
          {
            "type" => "input",
            "block_id" => "incident_commander",
            "element" => {
              "type" => "users_select",
              "action_id" => "incident_commander_input",
              "initial_user" => initial_user_id
            }.compact,
            "label" => {
              "type" => "plain_text",
              "text" => "Incident Commander"
            }
          }
        ],
        "submit" => {
          "type" => "plain_text",
          "text" => "Submit"
        }
      }
    }
  end
end
