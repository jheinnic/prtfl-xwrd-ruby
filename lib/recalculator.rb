require 'em-websocket'

class Recalculator
  def self.run
    puts "Main"
    EM.run {
      puts "EM Run Body"
      EM::WebSocket.run(:host => "0.0.0.0", :port => 8080) do |ws|
        puts "EM WS Run Body"
    
        ws.onerror { |msg| puts "Error: #{msg}" }
    
        ws.onopen { |handshake|
          puts "WebSocket connection open"
    
          # Access properties on the EM::WebSocket::Handshake object, e.g.
          # path, query_string, origin, headers
    
          # Publish message to the client
          ws.send "Hello Client, you connected to #{handshake.path}"
          if (handshake.path != '/crossword/recalculator') 
            puts "Bad path <#{handshake.path}>"
            ws.close();
          end
        }
    
        ws.onclose { puts "Connection closed" }
    
        ws.onmessage { |msg|
          puts "Recieved message: #{msg}"
    
          # Extract the ID, recalculate, and return.
          # TODO: Handle consecutive requests for the same ID
          ws.send ({:bonus_word => 'POKER', :payout01 => 10, :payout02 => 9, :payout03 => 8, :bonus_value => 2, :id => msg.id});
        }
      end
    }
  end
end
