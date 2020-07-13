#!/usr/bin/env bash

# Any subsequent commands which fail will cause the shell script to exit immediately
set -euo pipefail

# When the script exits or errors out, make sure to do the cleanup
trap cleanup EXIT

# platform should be one of "linux" or "darwin"
declare platform="$1"

cleanup() {
  echo "running cleanup"

  # Try stopping Xvfb only for Linux platform
  if [[ "$platform" == "linux" ]]
  then
    # This step might fail since Xvfb might not be running
    pkill Xvfb || true
  fi
}

sanity() {
  if [[ ! -d "src/electron" ]]
  then
    echo "Not in the right directory: $PWD, expected to src/electron to exist"
    exit 1
  fi
}

buildAndUpload() {
  echo "Building for $platform x64"
  pwd
  echo "--- Swtiching directory <pipeline>/src/electron"
  cd src/electron

  echo "--- Removing and adding origin"
  git remote remove origin
  git remote add origin https://github.com/postmanlabs/electron
  
  echo "--- Setting upstream branch"
  git fetch
  git checkout $BUILDKITE_BRANCH
  git branch --set-upstream-to origin/$BUILDKITE_BRANCH

  echo "git pull"
  git pull
  
  echo "--- Running gclient sync step"
  gclient sync -f

  echo "--- Swtiching directory <pipeline>/src"
  cd ..
  
  export CHROMIUM_BUILDTOOLS_PATH="$PWD/buildtools"

  echo "--- Running cleanup old files"
  rm -rf out

  echo "--- Running gn checks"
  gn gen out/Release --args="import(\"//electron/build/args/release.gn\")"
  gn check out/Release //electron:electron_lib
  gn check out/Release //electron:electron_app
  gn check out/Release //electron:manifests
  gn check out/Release //electron/shell/common/api:mojo

  echo "--- Electron build"
  ninja -C out/Release electron

  echo "--- Strip Electron binaries (Linux)"
  if [[ "$platform" == "linux" ]]
  then
    electron/script/copy-debug-symbols.py --target-cpu="x64" --out-dir=out/Release/debug --compress
    electron/script/strip-binaries.py -d out/Release
    electron/script/add-debug-link.py --target-cpu="x64" --debug-dir=out/Release/debug
  fi

  echo "--- Build Electron distributed binary"
  ninja -C out/Release electron:electron_dist_zip

  if [[ "$platform" == "linux" ]]
  then
    target_os=linux
  else
    target_os=mac
  fi

  echo "--- Build chromedriver"
  ninja -C out/Release chrome/test/chromedriver
  [[ "$platform" == "linux" ]] && electron/script/strip-binaries.py --target-cpu="x64" --file $PWD/out/Release/chromedriver
  ninja -C out/Release electron:electron_chromedriver_zip

  echo "--- Build ffmpeg"
  gn gen out/ffmpeg --args="import(\"//electron/build/args/ffmpeg.gn\")"
  ninja -C out/ffmpeg electron:electron_ffmpeg_zip
  

  echo "--- Build mksnapshot"
  ninja -C out/Release electron:electron_mksnapshot

  if [[ "$platform" == "linux" ]]
  then
    electron/script/strip-binaries.py --file $PWD/out/Release/mksnapshot
    electron/script/strip-binaries.py --file $PWD/out/Release/v8_context_snapshot_generator
  fi
  ninja -C out/Release electron:electron_mksnapshot_zip
  

  echo "--- Generate type declarationsp (Linux)"
  if [[ "$platform" == "linux" ]]
  then
    cd electron
    node script/yarn create-typescript-definitions
    cd ../
  fi

  echo "--- Upload artifacts"
  buildkite-agent artifact upload out/Release/dist.zip 
  buildkite-agent artifact upload out/Release/chromedriver.zip 
  buildkite-agent artifact upload out/ffmpeg/ffmpeg.zip 
  buildkite-agent artifact upload out/Release/mksnapshot.zip 
  buildkite-agent artifact upload electron/electron-api.json 
  buildkite-agent artifact upload electron/electron.d.ts
}

main() {
  sanity
  buildAndUpload
}

main
