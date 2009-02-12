#! /usr/bin/env ruby

require 'rubygems'
require 'aim'

AIM.user( :bob, 'secret' ).

  when :im_received do |im|
    im.reply "thanks for the message!"
  end.

  when :something_else do

  end.

  log_chat_room :some_room
