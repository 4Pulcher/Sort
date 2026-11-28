#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V3.4.sh                                                      #
# Version : 3.4                                                               #
# Desc    : Launcher / wrapper                                                #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

if [ $# -gt 0 ]; then
	${0%/*}/Sort.sh --mode=remove --recursive --replace --dirs=mime --subdirs=format+size --rename=md5sum --extension=mime $@
else
	if [ -d "./2SORT/" ]; then
		${0%/*}/Sort.sh --mode=remove --recursive --replace --dirs=mime --subdirs=format+size --rename=md5sum --extension=mime ./2SORT/
	else
		echo
		echo "Nothing to do!"
		echo
	fi
fi

echo "Thanks for using HEjder scripts!"
