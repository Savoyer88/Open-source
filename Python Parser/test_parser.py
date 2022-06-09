import parser
block_id=parser.BlockIDInfo()
with open('blkid.sample','r') as f:
    content=f.read().split("\n")
block_id.parse(content)

print(block_id.data[0])
print(block_id.data[0]['TYPE'])
print(block_id.filter('ext3'))

        # Setting pytest framework
        #   Pytest 1
def test_index1():
    assert block_id.data[0]=={'NAME': '/dev/sda1', 'UUID': '3676157d-f2f5-465c-a4c3-3c2a52c8d3f4', 'TYPE': 'xfs'}
        #   Pytest 2
def test_index2():
    assert block_id.data[0]['TYPE']=='xfs'
        #  Pytest 3
def test_index3():
    assert block_id.filter('ext3')==[{'LABEL': '/u02', 'UUID': '004d0ca3-373f-4d44-a085-c19c47da8b5e', 'TYPE': 'ext3', 'NAME': '/dev/cciss/c0d1p3'}, {'LABEL': '/u01', 'UUID': 'ffb8b27e-5a3d-434c-b1bd-16cb17b0e325', 'TYPE': 'ext3', 'NAME': '/dev/cciss/c0d1p2'}, {'UUID': 'f8508c37-eeb1-4598-b084-5364d489031f', 'TYPE': 'ext3', 'NAME': '/dev/block/253:1'}]
