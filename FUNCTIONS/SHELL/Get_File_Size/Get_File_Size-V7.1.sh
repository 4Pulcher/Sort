Get_File_Size() { stat -c %s "$1" 2>/dev/null || printf "0"; }
