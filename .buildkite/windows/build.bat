SETLOCAL ENABLEDELAYEDEXPANSION

REM (@TODO check do we need to cleanup everything or just the dist & out directories)
echo "Cleaning up"
CALL npm run clean
if %errorlevel% neq 0 exit /b %errorlevel%

echo "Running bootstrap command"
CALL python script\bootstrap.py -v
if %errorlevel% neq 0 exit /b %errorlevel%

echo "Building electron in debug mode"
CALL python script\build.py -c D
if %errorlevel% neq 0 exit /b %errorlevel%

echo "Uploading artifacts"
CALL buildkite-agent artifact upload "out/D/electron.exe"
if %errorlevel% neq 0 exit /b %errorlevel%

exit /b