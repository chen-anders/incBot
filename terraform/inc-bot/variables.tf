variable "name" {
  type = string
}

variable "secrets_key" {
  type = string
}

# Channel ID can be retrieved via right-clicking a channel's name, navigating to Copy -> Copy Link
# Example Link: https://my-workspace.slack.com/archives/C111HSSGZCM
# Channel ID in Example Link is: C111HSSGZCM
variable "incident_broadcast_channel_id" {
  type        = string
  description = "Central #incidents channel ID to broadcast incident-related events to."
  default     = ""
}


variable "pagerduty_email" {
  type        = string
  description = "Email to be using in the from-header during incident creation"
}
