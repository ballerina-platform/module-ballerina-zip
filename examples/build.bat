@echo off
setlocal
setlocal EnableDelayedExpansion

:: Define directories
set BAL_EXAMPLES_DIR=%~dp0
for %%I in ("%BAL_EXAMPLES_DIR%..") do set BAL_REPO_DIR=%%~fI
for %%I in ("%BAL_REPO_DIR%") do set BAL_REPO_NAME=%%~nxI
set BAL_HOME_DIR=%BAL_REPO_DIR%\ballerina
set BAL_CENTRAL_DIR=%USERPROFILE%\.ballerina\repositories\central.ballerina.io

:: Ensure a command is provided
if "%~1"=="" (
    echo Invalid command provided. Please provide "build" or "run" as the command.
    exit /b 1
)

:: Set the Ballerina command
if "%~1"=="build" (
    set BAL_CMD=build
) else if "%~1"=="run" (
    set BAL_CMD=run
) else (
    echo Invalid command provided: "%~1". Please provide "build" or "run" as the command.
    exit /b 1
)

:: Read Ballerina package name
for /f "tokens=2 delims== " %%A in ('findstr /r "^name" "%BAL_HOME_DIR%\Ballerina.toml"') do (
    set BAL_PACKAGE_NAME=%%~A
)

:: This package sets `isConnector = true`, so the Ballerina Gradle plugin builds the module inside
:: the `ballerina/ballerina` image rather than with the host `bal`. Every `bal` invocation here goes
:: through the same image, for the same two reasons the plugin does it:
::
::   - the distribution is the one pinned in `gradle.properties`, so packing the module does not
::     rewrite `Dependencies.toml` the way a mismatched host `bal` would, and
::   - the module is packed and pushed under the paths it was built with, so its platform
::     dependencies are found where the bala says they are.
::
:: Unlike `build.sh`, nothing here runs as a particular user or hands ownership back: a bind mount
:: from a Windows filesystem does not carry the container's ownership through to the host, so what
:: the module build wrote as root is not root-owned here and does not block a later `bal pack`.
where docker >nul 2>&1
if errorlevel 1 (
    echo Error: docker is required to build the examples, as it is to build the module.
    exit /b 1
)

:: The image tag is resolved the way the Gradle plugin resolves it: the pinned language version,
:: except that a timestamped version is only published as `nightly`.
for /f "tokens=2 delims==" %%A in ('findstr /r "^ballerinaLangVersion" "%BAL_REPO_DIR%\gradle.properties"') do (
    set BAL_LANG_VERSION=%%A
)
set BAL_LANG_VERSION=!BAL_LANG_VERSION: =!
if "!BAL_LANG_VERSION!"=="" (
    echo Error: ballerinaLangVersion not found in %BAL_REPO_DIR%\gradle.properties
    exit /b 1
)
echo !BAL_LANG_VERSION! | findstr /c:"-" >nul
if errorlevel 1 (
    set BAL_IMAGE=ballerina/ballerina:!BAL_LANG_VERSION!
) else (
    set BAL_IMAGE=ballerina/ballerina:nightly
)

:: The repository is mounted where the Gradle plugin mounts it, so the build caches the module build
:: left behind stay valid. `~/.ballerina` is mounted as well, because that is where the module is
:: pushed and where the examples then resolve it from, and it has to survive the container.
set BAL_CONTAINER_DIR=/home/ballerina/%BAL_REPO_NAME%
if not exist "%USERPROFILE%\.ballerina" mkdir "%USERPROFILE%\.ballerina"
set DOCKER_RUN=docker run --rm -v "%BAL_REPO_DIR%":%BAL_CONTAINER_DIR% -v "%USERPROFILE%\.ballerina":/home/ballerina/.ballerina

:: Push the package to the local repository
echo Packing and pushing the Ballerina package...
%DOCKER_RUN% -w %BAL_CONTAINER_DIR%/ballerina %BAL_IMAGE% bal pack || exit /b !ERRORLEVEL!
%DOCKER_RUN% -w %BAL_CONTAINER_DIR%/ballerina %BAL_IMAGE% bal push --repository=local || exit /b !ERRORLEVEL!

:: Remove the cache directories in the repositories
for /d %%D in ("%BAL_CENTRAL_DIR%\cache-*") do (
    if exist "%%D" (
        rmdir /s /q "%%D"
    )
)
echo Successfully cleaned the cache directories

:: Create the package directory in the central repository
if not exist "%BAL_CENTRAL_DIR%\bala\ballerina\%BAL_PACKAGE_NAME%" (
    mkdir "%BAL_CENTRAL_DIR%\bala\ballerina\%BAL_PACKAGE_NAME%"
)

:: Update the central repository
set BAL_DESTINATION_DIR=%BAL_CENTRAL_DIR%\bala\ballerina\%BAL_PACKAGE_NAME%
set BAL_SOURCE_DIR=%USERPROFILE%\.ballerina\repositories\local\bala\ballerina\%BAL_PACKAGE_NAME%
if exist "%BAL_DESTINATION_DIR%" (
    rmdir /s /q "%BAL_DESTINATION_DIR%"
)
if exist "%BAL_SOURCE_DIR%" (
    xcopy /e /i "%BAL_SOURCE_DIR%" "%BAL_DESTINATION_DIR%"
)
echo Successfully updated the local central repositories

echo %BAL_DESTINATION_DIR%
echo %BAL_SOURCE_DIR%

:: Loop through examples in the examples directory
set ERROR_OCCURRED=0
for /d %%D in ("%BAL_EXAMPLES_DIR%*") do (
    if not "%%~nxD"=="build" (
        echo Processing example: %%~nxD
        %DOCKER_RUN% -w %BAL_CONTAINER_DIR%/examples/%%~nxD %BAL_IMAGE% bal !BAL_CMD!
        if errorlevel 1 (
            set ERROR_OCCURRED=1
        )
    )
)
if %ERROR_OCCURRED%==1 (
    echo An error occurred during the execution of the loop.
    exit /b 1
)

:: Remove generated JAR files
for %%F in ("%BAL_HOME_DIR%\*.jar") do (
    del "%%F"
)
