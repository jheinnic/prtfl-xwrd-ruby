require 'recalculator'

namespace :crosswords do
  desc 'Launch the recalculation websocket'
  task :recalc => :environment do
    puts "Before Launching"
    Recalculator.run
    puts "After Stopping"
  end
end

