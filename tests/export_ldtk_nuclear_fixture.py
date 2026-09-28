"""Validation-only export of the pinned NuclearBlaze single-frame indexed fixture.
Not a general Aseprite decoder. Assertions deliberately reject other layouts.
Format: https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md
"""
from pathlib import Path
import struct,zlib,hashlib,sys
if len(sys.argv)!=3: raise SystemExit('Usage: export_ldtk_nuclear_fixture.py input.aseprite output.png')
source=Path(sys.argv[1])
b=source.read_bytes()
if hashlib.sha256(b).hexdigest()!='8baf4d3f0c5b2784843e9523fea29dcaed16d9d0206cfffc3c83cedd34b43e65':
	raise SystemExit('This test utility only accepts the pinned upstream NuclearBlaze fixture')
assert struct.unpack_from('<H',b,4)[0]==0xa5e0
frames,w,h,depth=struct.unpack_from('<HHHH',b,6)
assert (frames,w,h,depth)==(1,576,544,8)
transparent=b[28];pos=144;palette={};cel=None;layers=0
while pos<len(b):
	size,kind=struct.unpack_from('<IH',b,pos);d=b[pos+6:pos+size];pos+=size
	if kind==0x2019:
		count,first,last=struct.unpack_from('<III',d);offset=20
		for i in range(first,last+1):
			flags=struct.unpack_from('<H',d,offset)[0];offset+=2
			assert flags==0
			palette[i]=d[offset:offset+4];offset+=4
	elif kind==0x2004:
		flags,typ,child,_,_,blend=struct.unpack_from('<6H',d)
		assert flags&1 and typ==child==blend==0 and d[12]==255
		layers+=1
	elif kind==0x2005:
		assert cel is None
		layer,x,y,alpha,typ=struct.unpack_from('<HhhBH',d)
		cw,ch=struct.unpack_from('<HH',d,16)
		assert layer==0 and alpha==255 and typ==2 and x>=0 and y>=0 and x+cw<=w and y+ch<=h
		indices=zlib.decompress(d[20:]);assert len(indices)==cw*ch
		cel=(x,y,cw,ch,indices)
assert layers==1 and cel and palette
rgba=bytearray(w*h*4);x,y,cw,ch,indices=cel
for j,index in enumerate(indices):
	if index==transparent:continue
	dest=((y+j//cw)*w+x+j%cw)*4
	rgba[dest:dest+4]=palette[index]
assert sum(rgba[3::4])>0
raw=b''.join(b'\0'+rgba[row*w*4:(row+1)*w*4] for row in range(h))
def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
out=Path(sys.argv[2])
out.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))
print('source SHA256',hashlib.sha256(b).hexdigest())
print('PNG SHA256',hashlib.sha256(out.read_bytes()).hexdigest())
