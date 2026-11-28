#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V3.2.sh                                                      #
# Version : 3.2                                                               #
# Desc    : Launcher / wrapper                                                #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################
# By HEjder

[ $# -gt 0 ] && ${0%/*}/Sort.sh --mode=move --recursive --replace --dirs=mime --subdirs=size --rename=md5 --extension=mime-sub $@ || printf "\nPlease specify files/directories!\n\n"

echo "Thanks for using HEjder scripts!"
