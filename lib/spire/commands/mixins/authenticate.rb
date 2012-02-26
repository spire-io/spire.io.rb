require "yaml"

class Spire
  module Commands
    module Mixins
      module Authenticate
        
        def self.included(target)
          target.module_eval do
            
            include Mixlib::CLI
            
            option :email, 
              :short => "-e EMAIL",
              :long  => "--email EMAIL",
              :description => "The email for your account"

            option :password, 
              :short => "-p PASSWORD",
              :long  => "--password PASSWORD",
              :description => "The password for your account"

            option :secret,
              :short => "-s SECRET",
              :long => "--secret SECRET",
              :description => "The account secret for your account"
          end
  
        end
        
        def connect
          if config[:email]
            if !config[:password]
              config[:password] = ask("Password:") { |q| q.echo = false}
            end
            spire = Spire.new(CLI.url)
            spire.login(config[:email],config[:password])
            return spire
          else 
            if !config[:secret]
              if CLI.rc["secret"]
                config[:secret] = CLI.rc["secret"]
              else
                raise "No secret provided or found in ~/.spirerc"
              end
            end
            spire = Spire.new(CLI.url)
            spire.start(config[:secret])
            return spire
          end
        end
      end
    end
  end
end
            
          
