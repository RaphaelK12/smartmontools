@echo off
::
:: smartd warning script
::
:: Copyright (C) 2012-13 Christian Franke <smartmontools-support@lists.sourceforge.net>
::
:: This program is free software; you can redistribute it and/or modify
:: it under the terms of the GNU General Public License as published by
:: the Free Software Foundation; either version 2, or (at your option)
:: any later version.
::
:: You should have received a copy of the GNU General Public License
:: (for example COPYING); If not, see <http://www.gnu.org/licenses/>.
::
:: $Id$
::

set err=

:: Parse options
set dryrun=
if "%1" == "--dryrun" (
  set dryrun=t
  shift
)

if not "%1" == "" (
  echo smartd warning message script
  echo.
  echo Usage:
  echo set SMARTD_MAILER='Path to external script, empty for "blat"'
  echo set SMARTD_ADDRESS='Space separated mail adresses, empty if none'
  echo set SMARTD_MESSAGE='Error Message'
  echo set SMARTD_FAILTYPE='Type of failure, "EMailTest" for tests'
  echo set SMARTD_TFIRST='Date of first message sent, empty if none'
  echo :: set SMARTD_TFIRSTEPOCH='time_t format of above'
  echo set SMARTD_PREVCNT='Number of previous messages, 0 if none'
  echo set SMARTD_NEXTDAYS='Number of days until next message, empty if none'
  echo set SMARTD_DEVICEINFO='Device identify information'
  echo :: set SMARTD_DEVICE='Device name'
  echo :: set SMARTD_DEVICESTRING='Annotated device name'
  echo :: set SMARTD_DEVICETYPE='Device type from -d directive, "auto" if none'

  echo smartd_warning.cmd [--dryrun]
  goto EOF
)

if "%SMARTD_ADDRESS%%SMARTD_MAILER%" == "" (
  echo smartd_warning.cmd: SMARTD_ADDRESS or SMARTD_MAILER must be set
  goto EOF
)

:: USERDNSDOMAIN may be unset if running as service
if "%USERDNSDOMAIN%" == "" (
  for /f "delims== tokens=2 usebackq" %%d in (`WMIC PATH Win32_Computersystem WHERE "PartOfDomain=TRUE" GET Domain /VALUE 2^>nul ^| find "Domain=" 2^>nul`) do set USERDNSDOMAIN=%%~d
)

:: Format subject
set SMARTD_SUBJECT=SMART error (%SMARTD_FAILTYPE%) detected on host: %COMPUTERNAME%

:: Temp file for message
if not "%TMP%" == "" set SMARTD_FULLMSGFILE=%TMP%\smartd_warning-%DATE%-%RANDOM%.txt
if     "%TMP%" == "" set SMARTD_FULLMSGFILE=smartd_warning-%DATE%-%RANDOM%.txt

:: Format message
(
  echo This message was generated by the smartd service running on:
  echo.
  echo.   host name:  %COMPUTERNAME%
  if not "%USERDNSDOMAIN%" == "" echo.   DNS domain: %USERDNSDOMAIN%
  if     "%USERDNSDOMAIN%" == "" echo.   DNS domain: [Empty]
  if not "%USERDOMAIN%"    == "" echo.   Win domain: %USERDOMAIN%
  echo.
  echo The following warning/error was logged by the smartd service:
  echo.
  :: SMARTD_MESSAGE and SMARTD_DEVICEINFO may contain parentheses
  for %%m in ("%SMARTD_MESSAGE%") do echo.%%~m
  echo.
  echo Device info:
  for %%m in ("%SMARTD_DEVICEINFO%") do echo.%%~m
  set m=
  echo.
  echo For details see the event log or log file of smartd.
  if not "%SMARTD_FAILTYPE%" == "EmailTest" (
    echo.
    echo You can also use the smartctl utility for further investigation.
    if not "%SMARTD_PREVCNT%" == "0" echo The original message about this issue was sent at %SMARTD_TFIRST%
    if "%SMARTD_NEXTDAYS%" == "" (
      echo No additional messages about this problem will be sent.
    ) else ( if "%SMARTD_NEXTDAYS%" == "1" (
      echo Another message will be sent in 24 hours if the problem persists.
    ) else (
      echo Another message will be sent in %SMARTD_NEXTDAYS% days if the problem persists.
    ))
  )
) > "%SMARTD_FULLMSGFILE%"

if not "%dryrun%" == "" (
  echo %SMARTD_FULLMSGFILE%:
  type "%SMARTD_FULLMSGFILE%"
  echo --EOF--
)

:: Check first address
set first=
for /F "tokens=1*" %%a in ("%SMARTD_ADDRESS%") do (set first=%%a)
set wtssend=
if "%first%" == "console"   set wtssend=-c
if "%first%" == "active"    set wtssend=-a
if "%first%" == "connected" set wtssend=-s
set first=

if not "%wtssend%" == "" (
  :: Show Message box(es) via WTSSendMessage()
  if not "%dryrun%" == "" (
    echo call wtssendmsg %wtssend% "%SMARTD_SUBJECT%" - ^< "%SMARTD_FULLMSGFILE%"
  ) else (
    call wtssendmsg %wtssend% "%SMARTD_SUBJECT%" - < "%SMARTD_FULLMSGFILE%"
    if errorlevel 1 set err=t
  )
  :: Remove first address
  for /F "tokens=1*" %%a in ("%SMARTD_ADDRESS%") do (set SMARTD_ADDRESS=%%b)
)
set wtssend=

:: Make comma separated address list
set SMARTD_ADDRCSV=
if not "%SMARTD_ADDRESS%" == "" set SMARTD_ADDRCSV=%SMARTD_ADDRESS: =,%

:: Use blat mailer by default
if not "%SMARTD_ADDRESS%" == "" if "%SMARTD_MAILER%" == "" set SMARTD_MAILER=blat

:: Send mail or run command
if not "%SMARTD_ADDRCSV%" == "" (

  :: Send mail
  if not "%dryrun%" == "" (
    echo call "%SMARTD_MAILER%" - -q -subject "%SMARTD_SUBJECT%" -to "%SMARTD_ADDRCSV%" ^< "%SMARTD_FULLMSGFILE%"
  ) else (
    call "%SMARTD_MAILER%" - -q -subject "%SMARTD_SUBJECT%" -to "%SMARTD_ADDRCSV%" < "%SMARTD_FULLMSGFILE%"
    if errorlevel 1 set err=t
  )

) else ( if not "%SMARTD_MAILER%" == "" (

  :: Run command
  if not "%dryrun%" == "" (
    echo call "%SMARTD_MAILER%" ^<nul
  ) else (
    call "%SMARTD_MAILER%" <nul
    if errorlevel 1 set err=t
  )

))

del "%SMARTD_FULLMSGFILE%" >nul 2>nul

:EOF
if not "%err%" == "" goto ERROR 2>nul
