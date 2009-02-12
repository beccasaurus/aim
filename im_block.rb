# this is the block that'll be called whenever we reload!
#
# this means we can update code  :)

im_user $authorized_user, "#{screenname} bot started / reloaded @ #{ Time.now }"

self.when :im do |message, buddy|

  if buddy.screen_name == $authorized_user

    if message =~ /reload!/
      buddy.send_im 'reloading bot ...'
      AIM.reload! # this is more helpful if we're dynamically loading rules from another file
    end

    if message =~ /^!/ 
      buddy.send_im "command received: #{ message }"
    end

  end
end
