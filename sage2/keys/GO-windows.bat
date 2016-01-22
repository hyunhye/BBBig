REM Must be run as administrator
pushd %~dp0
call init_webserver.bat 172.30.1.59
call init_webserver.bat 127.0.0.1
