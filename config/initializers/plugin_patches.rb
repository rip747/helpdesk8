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

# rails-timeago
module Rails
  module Timeago
    module Helper
      # Return a JavaScript tag to set jQuery timeago locale.
      def timeago_script_tag(**kwargs)
        javascript_tag("import jQuery from \"jquery\"; jQuery.timeago.settings.lang=\"#{I18n.locale}\";", type: "module", **kwargs) if I18n.locale != 'en'
      end
    end
  end
end