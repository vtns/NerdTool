#!/usr/bin/env /bin/bash
xcodebuild -alltargets clean
xcodebuild -configuration Release -target NerdTool
