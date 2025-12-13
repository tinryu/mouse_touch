@echo off
echo Adding Firewall Rule for Mouse Track Server...
netsh advfirewall firewall add rule name="Mouse Track Server" dir=in action=allow protocol=TCP localport=9090
netsh advfirewall firewall add rule name="Mouse Track Discovery" dir=in action=allow protocol=UDP localport=8988
echo Done.
pause
