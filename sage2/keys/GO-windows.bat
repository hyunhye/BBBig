REM Must be run as administrator
pushd %~dp0
call init_webserver.bat 192.168.0.44
call init_webserver.bat 127.0.0.1
