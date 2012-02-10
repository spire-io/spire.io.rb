class Spire
  module Commands
    module Mixins
      module Help
        def self.included(target)
          target.module_eval do
            include Mixlib::CLI
            option :help,
              :short => "-h",
              :long => "--help",
              :description => "Show this message",
              :on => :tail,
              :boolean => true,
              :show_options => true,
              :exit => 0
          end
        end
        
      end
    end
  end
end
            
