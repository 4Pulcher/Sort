#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V3.3.sh                                                      #
# Version : 3.3                                                               #
# Desc    : Launcher / wrapper                                                #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

[ $# -gt 0 ] && ${0%/*}/Sort.sh --mode=move --recursive --replace --dirs=mime --subdirs=size --rename=md5 --extension=mime $@ || ${0%/*}/Sort.sh --mode=move --recursive --replace --dirs=mime --subdirs=size --rename=md5 --extension=mime ./2SORT/

echo "Thanks for using HEjder scripts!"
