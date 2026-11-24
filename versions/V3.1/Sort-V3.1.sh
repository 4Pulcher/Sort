#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V3.1.sh                                                      #
# Version : 3.1                                                               #
# Desc    : Launcher / wrapper                                                #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################
# by HEjder

${0%/*}/2Sort.sh --Move --Recursive --Replace --Rename=sha256sum --Extension=mime --Dirs=mime --SubDirs=format+size $@

echo "Thanks for using HEjder scripts!"
