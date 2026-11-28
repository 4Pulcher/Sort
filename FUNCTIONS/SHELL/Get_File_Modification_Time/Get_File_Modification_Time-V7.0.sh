Get_File_Modification_Time() { stat -c %y "$1" 2>/dev/null; }
