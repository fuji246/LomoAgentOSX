#!/bin/bash

set -e

#rm -rf build/LomoAgent.dmg
appdmg LomoAgent/Assets.xcassets/dmg.json build/LomoAgent.dmg
dependencies/licenseDMG.py build/LomoAgent.dmg dependencies/lomoware_license.rtf

