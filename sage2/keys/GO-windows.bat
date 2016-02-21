REM Must be run as administrator
pushd %~dp0
call init_webserver.bat 192.168.56.1
call init_webserver.bat 127.0.0.1
