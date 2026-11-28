#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V3.0.sh                                                      #
# Version : 3.0                                                               #
# Desc    : Launcher / wrapper                                                #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

cd /LocaL/SSD

~/BASH/SortFiles-2.sh '--Move' '--Recursive' '--Replace' '--Rename=sha256sum' '--Extension=mime' '--SubDirs=mime' '--BySize' /LocaL/SSD

~/BASH/SortFiles-2.sh '--Move' '--Probe' '--Recursive' '--Replace' '--Rename=sha256sum' '--Extension=mime' '--SubDirs=mime' '--BySize' /LocaL/HDD/Personal
~/BASH/SortFiles-2.sh '--Move' '--Probe' '--Recursive' '--Replace' '--Rename=sha256sum' '--Extension=mime' '--SubDirs=mime' '--BySize' /LocaL/HDD/Public
~/BASH/SortFiles-2.sh '--Move' '--Probe' '--Recursive' '--Replace' '--Rename=sha256sum' '--Extension=mime' '--SubDirs=mime' '--BySize' /USB/Public
~/BASH/SortFiles-2.sh '--Move' '--Probe' '--Recursive' '--Replace' '--Rename=sha256sum' '--Extension=mime' '--SubDirs=mime' '--BySize' /USB/Various

echo "<===== STARTED! =====>"

echo "Thanks for using HEjder scripts!"
