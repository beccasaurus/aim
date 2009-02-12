#! /usr/bin/env ruby

require 'rubygems'
require 'aim'

AIM.
  
  as_user('bob', 'secret').
    
    log_chatroom('some-room').
    
    every(5.minutes) do
      im('suzy').with('hi suzy!')
    end.

    im('steve').with {|user| "hi #{ ... }!" }.

    when(:im_received) do |im|
      reply.with('hi, thanks for the message!')
    end
