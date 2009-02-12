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

$authorized_user = 'remitaylor'

AIM.login_as_user( screenname, password ) do

  eval( File.read( File.dirname(__FILE__) + '/im_block.rb' ) )

end
