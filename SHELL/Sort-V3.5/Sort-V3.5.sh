#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V3.5.sh                                                      #
# Version : 3.5                                                               #
# Desc    : Launcher / wrapper                                                #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

MYCMD=${0%/*}/Sort.sh --mode=remove --jobs=5 --recursive --replace --dirs=mime --subdirs=format+size --rename=md5sum --extension=mime

if [ $# -gt 0 ]; then
	$MYCMD $@
else
	if [ -d "./2SORT/" ]; then
		$MYCMD ./2SORT/
	else
		echo
		echo "Nothing to do!"
		echo
	fi
fi

echo "Thanks for using HEjder scripts!"
