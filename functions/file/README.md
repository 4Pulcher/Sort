# functions/file

> File attributes via coreutils / file(1)

A complete, standalone bag of file tools: MIME detection, name/extension splitting, sizes, timestamps, permissions, ownership, predicates and more. Every function takes a path as its first argument, prints its result on stdout and returns non-zero on failure (127 when the needed tool is missing).

## Functions

### Identity: MIME, type, encoding

- `Get_MIME`
- `Get_MIME_Main`
- `Get_MIME_Sub`
- `Get_File_Description`
- `Get_File_Encoding`
- `Get_File_Type`

### Name splitting

- `Get_File_Name`
- `Get_File_Base`
- `Get_File_Ext`
- `Get_File_Dir`

### Size

- `Get_File_Size`
- `Get_File_Size_Human`
- `Get_File_Block_Size`
- `Get_File_Line_Count`
- `Get_File_Header_Hex`

### Timestamps

- `Get_File_Birth`
- `Get_File_Creation_Time`
- `Get_File_Access_Time`
- `Get_File_Modification_Time`
- `Get_File_Modified_Epoch`
- `Get_File_Accessed_Epoch`
- `Get_File_Changed_Epoch`
- `Get_File_Age`
- `Get_Date_Part`

### Ownership and inode

- `Get_File_Perm`
- `Get_File_Owner`
- `Get_File_Inode`
- `Get_File_Links`
- `Get_Symlink_Target`

### Predicates

- `File_Exists`
- `File_Is_Symlink`
- `File_Is_Hidden`
- `File_Is_Empty`
- `File_Is_Readable`
- `File_Is_Writable`
- `File_Is_Executable`
- `File_Is_Text`
- `File_Is_Binary`

Total: 38 functions.