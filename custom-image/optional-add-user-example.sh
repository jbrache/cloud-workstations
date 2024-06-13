export groups=docker,sudo,users
useradd -m jose -G $groups --shell /bin/bash > /dev/null
passwd -d jose >/dev/null
# sudo su jose - # wrong
# The dash should go before the username, otherwise it doesn't
# load the user profile which is why the profile.d script didn't get executed
sudo su - jose # right

# Above works OK with --shell /bin/bash but not with --shell /usr/bin/zsh:
# useradd -m jose -G $groups --shell /usr/bin/zsh > /dev/null # Doesn't work with this sample

# If using another shell, i.e. zsh would need to adapt the this sample,
# the startup portions still be OK. Would need to plug something into
# /etc/zprofile or something if we want to support he and hoc command line useradd scenario