@ECHO OFF
SETLOCAL enabledelayedexpansion

SET        FILE_SETUP=".\WrtSettings.iss"
SET     FILE_SOLUTION="..\Source\WrtSettings.sln"
SET  FILES_EXECUTABLE="..\Binaries\WrtSettings.exe"
SET       FILES_OTHER="..\Binaries\ReadMe.txt"

SET    COMPILE_TOOL_1="%PROGRAMFILES(X86)%\Microsoft Visual Studio 14.0\Common7\IDE\devenv.exe"
SET    COMPILE_TOOL_2="%PROGRAMFILES(X86)%\Microsoft Visual Studio 14.0\Common7\IDE\WDExpress.exe"
SET        SETUP_TOOL="%PROGRAMFILES(x86)%\Inno Setup 5\iscc.exe"

SET       SIGN_TOOL_1="%PROGRAMFILES(X86)%\Windows Kits\10\bin\x86\signtool.exe"
SET       SIGN_TOOL_2="%PROGRAMFILES(X86)%\Windows Kits\8.1\bin\x86\signtool.exe"
SET       SIGN_TOOL_3="%PROGRAMFILES(X86)%\Windows Kits\8.0\bin\x86\signtool.exe"
SET         SIGN_HASH="C02FF227D5EE9F555C13D4C622697DF15C6FF871"
SET SIGN_TIMESTAMPURL="http://timestamp.comodoca.com/rfc3161"

SET        GIT_TOOL_1="%PROGRAMFILES%\Git\mingw64\bin\git.exe"


ECHO --- DISCOVER TOOLS
ECHO.

IF EXIST %COMPILE_TOOL_1% (
    ECHO Visual Studio 2015
    SET COMPILE_TOOL=%COMPILE_TOOL_1%
) ELSE (
    IF EXIST %COMPILE_TOOL_2% (
        ECHO Visual Studio Express 2015
        SET COMPILE_TOOL=%COMPILE_TOOL_2%
    ) ELSE (
        ECHO Cannot find Visual Studio^^!
        PAUSE && EXIT /B 255
    )
)

IF EXIST %SETUP_TOOL% (
    ECHO Inno Setup 5
) ELSE (
    ECHO Cannot find Inno Setup 5^^!
    PAUSE && EXIT /B 255
)

IF EXIST %SIGN_TOOL_1% (
    ECHO Windows SignTool 10
    SET SIGN_TOOL=%SIGN_TOOL_1%
) ELSE (
    IF EXIST %SIGN_TOOL_2% (
        ECHO Windows SignTool 8.1
        SET SIGN_TOOL=%SIGN_TOOL_2%
    ) ELSE (
        IF EXIST %SIGN_TOOL_3% (
            ECHO Windows SignTool 8.0
            SET SIGN_TOOL=%SIGN_TOOL_3%
        ) ELSE (
            ECHO Cannot find Windows SignTool^^!
            PAUSE && EXIT /B 255
        )
    )
)

IF EXIST %GIT_TOOL_1% (
    ECHO Git
    SET GIT_TOOL=%GIT_TOOL_1%
) ELSE (
    GIT_TOOL="git"
)

ECHO.
ECHO.


ECHO --- DISCOVER VERSION
ECHO.

FOR /F "delims=" %%N IN ('%GIT_TOOL% log -n 1 --format^=%%h') DO @SET VERSION_HASH=%%N%

IF NOT [%VERSION_HASH%]==[] (
    FOR /F "delims=" %%N IN ('%GIT_TOOL% rev-list --count HEAD') DO @SET VERSION_NUMBER=%%N%
    %GIT_TOOL% diff --exit-code --quiet
    IF ERRORLEVEL 1 SET VERSION_HASH=%VERSION_HASH%+
    ECHO %VERSION_HASH%
)

ECHO.
ECHO.


ECHO --- BUILD SOLUTION
ECHO.

RMDIR /Q /S "..\Binaries" 2> NUL
%COMPILE_TOOL% /Build "Release" %FILE_SOLUTION%
IF ERRORLEVEL 1 PAUSE && EXIT /B %ERRORLEVEL%

COPY ..\README.md ..\Binaries\ReadMe.txt > NUL
IF ERRORLEVEL 1 PAUSE && EXIT /B %ERRORLEVEL%

COPY ..\LICENSE.md ..\Binaries\License.txt > NUL
IF ERRORLEVEL 1 PAUSE && EXIT /B %ERRORLEVEL%

ECHO Completed.

ECHO.
ECHO.


CERTUTIL -silent -verifystore -user My %SIGN_HASH% > NUL
IF %ERRORLEVEL%==0 (
    ECHO --- SIGN SOLUTION
    ECHO.
    
    IF [%SIGN_TIMESTAMPURL%]==[] (
        %SIGN_TOOL% sign /s "My" /sha1 %SIGN_HASH% /v %FILES_EXECUTABLE%
    ) ELSE (
        %SIGN_TOOL% sign /s "My" /sha1 %SIGN_HASH% /tr %SIGN_TIMESTAMPURL% /v %FILES_EXECUTABLE%
    )
    IF ERRORLEVEL 1 PAUSE && EXIT /B %ERRORLEVEL%
) ELSE (
    ECHO --- DID NOT SIGN SOLUTION
    IF NOT [%SIGN_HASH%]==[] (
        ECHO.
        ECHO No certificate with hash %SIGN_HASH%.
    ) 
)
ECHO.
ECHO.


ECHO --- BUILD SETUP
ECHO.

RMDIR /Q /S ".\Temp" 2> NUL
CALL %SETUP_TOOL% /DVersionHash=%VERSION_HASH% /O".\Temp" %FILE_SETUP%
IF ERRORLEVEL 1 PAUSE && EXIT /B %ERRORLEVEL%

FOR /F %%I IN ('DIR ".\Temp\*.exe" /B') DO SET _SETUPEXE=%%I
ECHO Setup is in file %_SETUPEXE%

ECHO.
ECHO.


ECHO --- RENAME BUILD
ECHO.

SET _OLDSETUPEXE=%_SETUPEXE%
IF NOT [%VERSION_HASH%]==[] (
    SET _SETUPEXE=!_SETUPEXE:000=-rev%VERSION_NUMBER%-%VERSION_HASH%!
)
IF NOT "%_OLDSETUPEXE%"=="%_SETUPEXE%" (
    ECHO Renaming %_OLDSETUPEXE% to %_SETUPEXE%
    MOVE ".\Temp\%_OLDSETUPEXE%" ".\Temp\%_SETUPEXE%"
) ELSE (
    ECHO No rename needed.
)

ECHO.
ECHO.


CERTUTIL -silent -verifystore -user My %SIGN_HASH% > NUL
IF %ERRORLEVEL%==0 (
    ECHO --- SIGN SETUP
    ECHO.
    
    IF [%SIGN_TIMESTAMPURL%]==[] (
        %SIGN_TOOL% sign /s "My" /sha1 %SIGN_HASH% /v ".\Temp\%_SETUPEXE%"
    ) ELSE (
        %SIGN_TOOL% sign /s "My" /sha1 %SIGN_HASH% /tr %SIGN_TIMESTAMPURL% /v ".\Temp\%_SETUPEXE%"
    )
    IF ERRORLEVEL 1 PAUSE && EXIT /B %ERRORLEVEL%
) ELSE (
    ECHO --- DID NOT SIGN SETUP
)
ECHO.
ECHO.


ECHO --- BUILD ZIP
ECHO.

ECHO Zipping into %_SETUPEXE:.exe=.zip%
"%PROGRAMFILES%\WinRAR\WinRAR.exe" a -afzip -ep -m5 ".\Temp\%_SETUPEXE:.exe=.zip%" %FILES_EXECUTABLE% %FILES_OTHER%
IF ERRORLEVEL 1 PAUSE && EXIT /B %ERRORLEVEL%

ECHO.
ECHO.


ECHO --- RELEASE
ECHO.

MKDIR "..\Releases" 2> NUL
MOVE ".\Temp\*.*" "..\Releases\." > NUL
IF ERRORLEVEL 1 PAUSE && EXIT /B %ERRORLEVEL%
RMDIR /Q /S ".\Temp"

ECHO.


ECHO --- DONE
ECHO.

explorer /select,"..\Releases\%_SETUPEXE%"
