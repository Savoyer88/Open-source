import re
            # defining class
class BlockIDInfo():

    data = []
    def parse(self, content):
        blkid_output = []
        for line in (l for l in content if l.strip()):
           # print(line)
           # matching and extraction of data
            device_name, attributes = line.rsplit(":", 1)
            device = dict((k, v) for k, v in re.findall(r'([A-Z]+)=\"(\S+)\"', line))
            device['NAME'] = device_name.strip()
            blkid_output.append(device)

        self.data = blkid_output
            #setting type filter
    def filter(self, filt_type):
        return [r for r in self.data if r.get('TYPE') == filt_type]

