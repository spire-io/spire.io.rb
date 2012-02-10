require "yaml"
require "spire_io"
require "spire/commands/mixins/help"
require "mixlib/cli"

class Spire
  module Commands
    
    # This is the spire command
    class Register
      
      include Mixlib::CLI
      include Mixins::Help

      option :email, 
        :short => "-e EMAIL",
        :long  => "--email EMAIL",
        :required => true,
        :description => "The email for the account you're registering"

      option :password, 
        :short => "-p PASSWORD",
        :long  => "--password PASSWORD",
        :required => true,
        :description => "Set the password for managing this account"

      def self.run(args)
        self.new.run(args)
      end
      
      def run(args)
        parse_options(args)
        spire = Spire.new(CLI.url)
        spire.register(:email => config[:email], :password => config[:password])
        CLI.rc["key"] = spire.key
        CLI.save_rc
				$stdout.puts spire.key
      end
            
    end
  end
end