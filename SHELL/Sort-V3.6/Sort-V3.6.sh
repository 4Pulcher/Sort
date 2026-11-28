#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V3.6.sh                                                      #
# Version : 3.6                                                               #
# Desc    : Launcher / wrapper                                                #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################
# by HEjder

# FindAndRemove: find and remove
function FindAndRemove {
	~/BASH/Sort.sh --remove --recursive --replace --rename=sha256sum --extension=mime --dirs=mime --subdirs=format+size $@
}

if [ $# -gt 0 ]; then
	OIFS=$IFS
	IFS=$'\n\b'

	FindAndRemove $@

	IFS=$OIFS
fi

echo "Thanks for using HEjder scripts!"
