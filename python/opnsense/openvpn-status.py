#!/usr/local/bin/python3
#
# Checks to see if OpenVPN Client is enabled and working or not.
# I have not found a way to query the status of the "client1" openvpn in OPNSense.
#

import subprocess

ping_target = '10.8.1.1' # ProtonVPN Gateway

openvpn_enabled = subprocess.getoutput('/sbin/ifconfig ovpnc1 | grep -c UP')
if openvpn_enabled == "1":

    # Now check to see if OpenVPN is actually working:
    online = subprocess.run(['ping', '-q', '-n', '-c1', ping_target], stdout=subprocess.PIPE)
    #print(online.stdout)
    
    # returncode = zero (False) indicates ping success
    # returncode = non-zero (True) indicates ping failure
    if not online.returncode:
        print('on')
    else:
        print('off')

else:
    print('off')
