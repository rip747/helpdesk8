require_relative "boot"
require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Helpdesk8
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    config.assets.paths << Rails.root.join("vendor", "assets", "components")
    config.assets.paths << Rails.root.join("public", "uploads", "logos")


    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    config.to_prepare do
      Devise::Mailer.layout "mailer" # email.haml or email.erb
    end
  end
end

# old api
# module Api
#   class Application < Rails::Application
#     config.middleware.use Rack::Cors do
#       allow do
#         origins "*"
#         resource "*", headers: :any, methods: [ :get,
#             :post, :put, :delete, :options ]
#       end
#     end
#     config.active_record.raise_in_transactional_callbacks = true
#   end
# end
