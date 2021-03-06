SETLOCAL ENABLEDELAYEDEXPANSION

echo "Pre-Cleanup: Cleaning up only dist/* and out/*"
CALL npm run clean-build
if %errorlevel% neq 0 exit /b %errorlevel%

echo "Downloading the artifact"
CALL buildkite-agent artifact download out\D.zip .
if %errorlevel% neq 0 exit /b %errorlevel%

echo "Unzipping the artifact"
CALL powershell Expand-Archive -Force -LiteralPath out\D.zip -DestinationPath out\
if %errorlevel% neq 0 exit /b %errorlevel%

echo "Running test suite"
CALL python script\test.py --ci --rebuild_native_modules
if %errorlevel% neq 0 exit /b %errorlevel%

echo "Running verify ffmpeg"
CALL python script\verify-ffmpeg.py
if %errorlevel% neq 0 exit /b %errorlevel%

echo "Post-Cleanup: Cleaning up only dist/* and out/*"
CALL npm run clean-build

exit /b