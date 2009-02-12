#! /usr/bin/env ruby

require 'rubygems'
require File.dirname(__FILE__) + '/lib/aim'

puts "Welcome to AIM DSL Test"
puts ""

print " Screenname: "
  screenname = gets.strip

print "   Password: "
  system "stty -echo" # disable printing stdin
  password = gets.strip
  system "stty echo"  # enable print stdin
  puts ""

if screenname.empty? or password.empty?
  puts "I didn't get a screenname & password!"
  exit
end

AIM.login_as_user( screenname, password ) do
  
  im_user 'some user to IM', "hello!  the time is #{ Time.now }"

  log_chatroom 'some chat room to log into'

end
