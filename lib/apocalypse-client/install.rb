module Apocalyse
  module Client
    class Install
      def install!
        check_file_access   # Start of by checking if we can write the Cron job
        read_values         # Now ask the user for the configuration input
        validate            # Make sure the input is correct
        check_server        # Check if the provided server is accessible 
        write_host_file     # Write the configuration file for this host
        install_cron_job    # Finally install the Cronjob
        
        puts "All done.."
      rescue Exception => e
       puts e.message
      end

      def update!
        puts "Updating..."
        #  Nothing here as nothing needs to be updated yet.
      end
      
      def self_update!
        update_gem         # gem update apocalypse-client
        update_command     # Do a update command
        
      rescue Exception => e
        puts e.message
      end
      
      protected 
        # Read the configuration for this server provided by the user
        def read_values
          # Read the Apocalypse Server information
          url        = read_user_input("Enter The full address of the Apocalypse server: ").downcase
          @port      = read_user_input("Enter The port number of the Apocalypse server {{default}}: ", "80")
          
          # Cleanup the user input for the server input
          url         = url.gsub(/http:\/\/(.+?$)/, "\\1") if url =~ /^http:\/\//i
          @address    = url.gsub(/\/$/, "")

          # HTTP auth variables
          @username = read_user_input("Enter your username {{default}}: "     , `whoami`)
          @password = read_user_input("Enter your password: "                 , "", false)
          
          # This servers hostname
          @hostname = read_user_input("Enter The full hostname(FQDN) {{default}}: " , `hostname`).downcase
        end
      
        # Ask the user if the input is valid
        # If so write the host file and continue installing
        def validate
          2.times { puts }
          puts <<-EOF
You have entered the following information
Apocalypse server       : #{@address}
Apocalypse server port  : #{@port}
Apocalypse username     : #{@username}
Apocalypse password     : #{'*' *@password.length}
This Server' hostname   : #{@hostname}
EOF

          print "Is this correct? [no]: "
          raise Exception.new("Aborted by user.") unless gets =~ /^y(?:es|)$/
          puts
        end
        
        # Check if the server address is correct
        def check_server
          raise Exception.new("Could not reach Apocalypse server please check the address and port and try again.") unless server_reachable?
        end

        # Write the user provided information to a YAML file
        def write_host_file
          puts "Writing Apocalypse host file..."
          host_config   = {
                           :hostname        => @hostname,
                           :server_address  => @address, 
                           :port            => @port,                           
                           :username        => @username, 
                           :password        => @password
                          }
          file          = File.open(::Apocalypse::Client.host_file, "w") do |f|
            f.write host_config.to_yaml
          end          
        end
        
        def check_file_access
          writeable = `if [ \`touch #{::Apocalypse::Client.cron_job_file} 2> /dev/null; echo "$?"\` -eq 0 ]; then
          echo "true"
          else
          echo "false"
          fi`          
          unless writeable.chomp.eql? "true"
           raise Exception.new("You don't have permission to write #{::Apocalypse::Client.cron_job_file}. Either run the script as root or make #{::Apocalypse::Client.cron_job_file} writeable for this user.")
          end
        end
        
        def install_cron_job
          `echo "#{::Apocalypse::Client.cron_job_command}" > #{::Apocalypse::Client.cron_job_file}`
        end
        
        def update_gem
          if ::Apocalypse::Client.rvm?  
            puts "Updating gem using RVM.."
            `PATH=$PATH:/sbin:/usr/sbin rvm use $RUBY_VERSION; /usr/local/bin/rvm gem update apocalypse-client > /dev/null`
          else
            puts "Updating system gem.."          
            `PATH=$PATH:/sbin:/usr/sbin; sudo gem update apocalypse-client > /dev/null`
          end          
        end
        
        def update_command
          if ::Apocalypse::Client.rvm?  
            `PATH=$PATH:/sbin:/usr/sbin rvm use $RUBY_VERSION; apocalypse-client update > /dev/null`
          else
            `PATH=$PATH:/sbin:/usr/sbin /usr/bin/env apocalypse-client update > /dev/null`
          end          
        end
        
      private
        # Read the user input from the console and return either the default value or the user input
        def read_user_input(message, default = "", show_input = true)
          print interpolate_message(message, default)
          show_input ? gets : silent_command { gets }
          ($_.chomp.empty?) ? default.chomp : $_.chomp
        end
        
        # Interpolate the message with the given string replacing: {{var}} with: (var: #{str})
        def interpolate_message(message, str)
          message.gsub(/\{\{(.+?)\}\}/, (str.empty?) ? "" : "(\\1: #{str.chomp})")
        end
        
        # Execute the command in the given block without returning writing anything to stdout
        def silent_command(&cmd)
          system "stty -echo"          
          yield
          system "stty echo"
          puts
        end
        
        # Check if the server is reachable before continuing with the installation
        def server_reachable?
          puts "Checking #{@address}:#{@port}"
          res = Net::HTTP.start(@address, @port) {|http| http.get('/') }
          return res.code == "200"
        end
    end
  end
end


