require "spire_io"
require "spire/commands/mixins/authenticate"
require "spire/commands/mixins/help"
require "mixlib/cli"
require "highline/import"

require "irb"
require "irb/completion"

class Spire
  module Commands
    
    # This is the spire command
    class Console
      
      include Mixins::Authenticate
      include Mixins::Help

      def self.run(args)
        self.new.run(args)
      end
      
      def run(args)
        parse_options(args)
        $spire = connect
        ARGV.clear
        IRB.start
      end
            
    end
  end
end