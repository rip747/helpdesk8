# Load the Rails application.
require_relative "application"
# Needed for backwards compatability with rails-settings-cached gem
require_relative "../app/models/app_settings"

# Initialize the Rails application.
Rails.application.initialize!

# Get the current tag version
VERSION = "0.0.1"
REVISION = `git log --pretty=format:'%h' -n 1`
APP_VERSION = "#{VERSION}:#{REVISION}"
