require "spire/commands/register"
require "spire/commands/console"

class Spire
  module Commands
    
    # This is the spire command
    module CLI

      COMMANDS = {
        "register" => Spire::Commands::Register,
        "console" => Spire::Commands::Console
      }
      
      def self.run(subcommand,*args)
        if command = COMMANDS[subcommand]
          begin
            command.run(args)
          rescue => e
            $stderr.puts "spire: #{e.message}"
            exit(-1)
          end
        else
          usage "#{subcommand} is not a supported command"
        end
      end
      
      def self.rc
        @rc ||= (YAML.load_file(File.expand_path("~/.spirerc")) rescue {})
      end
      
      def self.save_rc
        File.open(File.expand_path("~/.spirerc"),"w") { |f| YAML.dump(rc,f) }
      end
      
      def self.url
        rc["url"]||"https://api.spire.io"
      end
      
      def self.usage(message)
        $stderr.puts "spire: #{message}"
        $stderr.puts <<-eos
Usage: spire <subcommand> <options>

The spire command provides command line access to the spire.io API. 

Valid commands:

    register     Register a new account
    console      Open up an IRB session with an open spire session.
    
You can get more options for any command with --help or -h.
eos
        exit(-1)
      end
      
    end
  end
end