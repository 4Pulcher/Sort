Get_File_Birth() { stat -c '%W' -- "$1" 2>/dev/null; }
