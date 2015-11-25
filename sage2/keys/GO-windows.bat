REM Must be run as administrator
pushd %~dp0
call init_webserver.bat 192.168.0.47
call init_webserver.bat 127.0.0.1
