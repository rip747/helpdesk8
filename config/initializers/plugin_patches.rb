# themes_on_rails
module ThemesOnRails
  class ActionController
    class << self
      private
      def before_filter_method(options)
        case Rails::VERSION::MAJOR
        when 3
          options.delete(:prepend) ? :prepend_before_filter : :before_filter
        else
          options.delete(:prepend) ? :prepend_before_action : :before_action
        end
      end
    end
  end
end

# twitter-bootstrap-rails
gem_dir = Gem::Specification.find_by_name("twitter-bootstrap-rails").gem_dir
require "#{gem_dir}/app/helpers/badge_label_helper"
