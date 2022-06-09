# -*- coding: utf-8 -*- \

class Parser(object):
    """
    Base class designed to be subclassed by parsers.

    IMPORTANT: DO NOT CHANGE THIS CLASS
    """

    def __init__(self, content):
        self.content = content

    def parse_content(self):
        """This method must be implemented by classes based on this class."""
        msg = "Parser subclasses must implement parse_content(self)."
        raise NotImplementedError(msg)


class BlockIDInfo(Parser):
    """Class to process the ``blkid`` command output.
    Attributes:
        data (list): A list containing a dictionary for each line of the output in
            the form::
                [
                    {
                        'NAME': "/dev/sda1"
                        'UUID': '3676157d-f2f5-465c-a4c3-3c2a52c8d3f4',
                        'TYPE': 'xfs'
                    },
                    {
                        'NAME': "/dev/cciss/c0d1p3",
                        'LABEL': '/u02',
                        'UUID': '004d0ca3-373f-4d44-a085-c19c47da8b5e',
                        'TYPE': 'ext3'
                    }
                ]
    """
    data = {}

    def parse_content(self):
        """
        TODO 1: Implement this method

        The goal of this method is to parse the `content` and assign it to a class attribute `data`.
        `data` is a list of dict: List containing dict for each line of command output (see class documentation).
        """

        self.data = {}  # remove this line

    def filter_by_type(self, fs_type):
        """
        # TODO 2: Implement this class
        list: Returns a list of all entries where TYPE = ``fs_type``.
        """
        return None  # remove this line


if __name__ == '__main__':
    # TODO 3: Read the content of the file: blkid.sample
    blkid_output = ""  # Replace by the content of the `blkid.sample` file

    block_id = BlockIDInfo(blkid_output)
    block_id.parse_content()

    # Output examples
    print(block_id.data[0])
    print(block_id.data[0]['TYPE'])
    print(block_id.filter_by_type('ext3'))
