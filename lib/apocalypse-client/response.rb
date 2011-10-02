module Apocalyse
  module Client
    class Response
      RESULT_OK               = 0
      RESULT_CLIENT_OUTDATED  = 1001
      
      def self.parse!(response)
        if response.code.to_i == 200
          response_obj = JSON.parse(response.body)
          unless response_obj["code"] == RESULT_OK
            perform!(response_obj["code"])
          end
        else
          resolve_invalid_response
        end
        
      rescue => e 
        resolve_invalid_response
      end

      def self.perform!(result_code)
        case result_code
          when RESULT_CLIENT_OUTDATED
            puts "Received update result code"            
            ::Apocalyse::Client::Install.new.self_update!

          else
            resolve_invalid_response
          end
      end

      def self.resolve_invalid_response
        puts "Invalid response, let's try to update."
        ::Apocalyse::Client::Install.new.self_update!
      end      
    end
  end
end   