#! /usr/bin/env ruby

require 'rubygems'
require 'aim'

AIM.login_as_user( 'bob', 'secret' ).and do

  log_chatroom :some_chatroom

  im_user :bob, 'hello bob!'

  when :IM_received, :from => 'bob' do |im|
    reply_with 'thanks for your message'
  end

end
