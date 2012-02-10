require "spire_io"
require "mixlib/cli"

class Spire
  module Commands
    
    # This is the spire command
    class Register
      
      include Mixlib::CLI

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

      option :help,
        :short => "-h",
        :long => "--help",
        :description => "Show this message",
        :on => :tail,
        :boolean => true,
        :show_options => true,
        :exit => 0

      def self.run(args)
        self.new.run(args)
      end
      
      def run(args)
        parse_options(args)
        @spire = Spire.new
        @spire.register(:email => config[:email], :password => config[:password])
				$stdout.puts @spire.key
      end
            
    end
  end
end