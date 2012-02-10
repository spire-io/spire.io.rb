require "spire/commands/register"

class Spire
  module Commands
    
    # This is the spire command
    module CLI

      COMMANDS = {
        "register" => Spire::Commands::Register
      }
      
      def self.run(subcommand,*args)
        if command = COMMANDS[subcommand]
          command.run(args)
        else
          usage "#{subcommand} is not a supported command"
        end
      end
      
      def self.usage(message)
        $stderr.puts message
        exit(-1)
      end
      
    end
  end
end