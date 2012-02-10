require "spire_io"
require "mixlib/cli"
require "highline/import"
require 'irb'
require 'irb/completion'

class Spire
  module Commands
    
    # This is the spire command
    class Console
      
      include Mixlib::CLI

      option :email, 
        :short => "-e EMAIL",
        :long  => "--email EMAIL",
        :required => true,
        :description => "The email for the account you want to use to login"

      option :password, 
        :short => "-p PASSWORD",
        :long  => "--password PASSWORD",
        :description => "The password for the account you want to use to login"

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
        if !config[:password]
          config[:password] = ask("Password:") { |q| q.echo = false}
        end
        $spire = Spire.new
        $spire.login(config[:email],config[:password])
        ARGV.clear
        IRB.start
      end
            
    end
  end
end