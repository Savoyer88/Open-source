Python class BlockIDInfo that parses the blkid command output. Typical output looks like:

The class has one attribute data which is a list representing each line
of the input data as a dict with keys corresponding to the keys in the
output.
The class must provide the ability to filter the blocks by type (see examples below).

>> block_id.data[0]
{'NAME': '/dev/sda1', 'UUID': '3676157d-f2f5-465c-a4c3-3c2a52c8d3f4', 'TYPE': 'xfs'}
    
>> block_id.data[0]['TYPE']
'xfs'
>> block_id.filter_by_type('ext3')
[{'NAME': '/dev/cciss/c0d1p3', 'LABEL': '/u02', 'UUID': '004d0ca3-373f-4d44-a085-c19c47da8b5e',
  'TYPE': 'ext3'},
 {'NAME': '/dev/block/253:1', 'UUID': 'f8508c37-eeb1-4598-b084-5364d489031f','TYPE': 'ext3'},
 {'NAME': '/dev/cciss/c0d1p2', 'LABEL': '/u01', 'UUID': 'ffb8b27e-5a3d-434c-b1bd-16cb17b0e325',
  'TYPE': 'ext3'}]

Input
The output of the command blkid. You can read the content of the file blkid.sample.

Output
A python object block_id that is an instance of the class BlockIDInfo 

Used Regexes to match and extract the data
Implemented unit tests using pytest 
