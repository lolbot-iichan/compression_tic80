from __future__ import print_function
from PIL import Image
from collections import defaultdict

def decode_img(fname):
    rgb = Image.open(fname).convert("RGB")
    colors = []
    countcolors = defaultdict(int)
    raw = []
    w,h = rgb.size[0],rgb.size[1]
    for j in range(rgb.size[1]):
        for i in range(rgb.size[0]):
            px = rgb.getpixel((i,j))
            countcolors[px] += 1
            if  px not in colors:
                colors += [px]
            idx = colors.index(px)
            raw += [idx]
    print(countcolors)
    for c,v in countcolors.items():
        if  v<10:
            for j in range(rgb.size[1]):
                for i in range(rgb.size[0]):
                    if  c == rgb.getpixel((i,j)):
                        print(i,j)
    return w,h,raw,colors
    
def print_raw(w,h,raw,colors):
    print(w,"x",h) 
#    for i in range(h):
#        for j in range(w):
#            print("%02d"%raw[i*w+j], end="")
#        print()
    for i in range(len(colors)):
        print(i,colors[i]) 

def dump(fname,bytes,fill=False):
    with open("out/"+fname,"wb") as f:
        print(len(bytes))
        f.write(chr(len(bytes)/256)+chr(len(bytes)%256))
        f.write(bytes)
        if fill:
            f.write(" "*(32640-f.tell()))

def encode_colors(colors):
    return chr(len(colors)) + "".join([chr(c[0])+chr(c[1])+chr(c[2]) for c in colors])

def encode_img(w,h,colors,bytes):
    return "I" + chr(w%256) + chr(h%256) + chr(w/256*16+h/256) + encode_colors(colors) + bytes

def encode_raw(raw):
    result = "N"
    for i in range(len(raw)/2):
        result += chr(raw[i*2+1]*16+raw[i*2])
    return result

def encode_rle(bytes,mask=0):
    result = ""
    chain = ""
    n = 1
    for x in bytes:
        if  chain and (chain[0]!=x or len(chain)>254-mask):
            result += chain[0]
            if  mask==0 or len(chain) > 1:
                result += chr(len(chain)+mask)
            n += 1
            chain = x
        else:
            chain += x
    result += chain[0]
    if  mask==0 or len(chain) > 1:
        result += chr(len(chain)+mask)
    return "R" + chr(n/256) + chr(n%256) + chr(mask) + result + chr(0)

def encode_bits(bits):
    if  len(bits)%8:
        bits   += [0]*(8-len(bits)%8)
    b = "".join([chr(sum([bits[8*i+j]*2**j for j in range(8)])) for i in range(len(bits)/8)])
    return chr(len(bits)//256//256)+chr(len(bits)//256%256)+chr(len(bits)%256)+b

def encode_lz77(bytes,win=1024,sz=64):
    result = ""
    chain = ""
    bits = []
    for i,x in enumerate([b for b in bytes]+[None]):
        w = bytes[0 if win>i else i-win:i]
        cut = w if len(w)<win else w[1:]
        if  x is not None and chain + x in cut and len(chain)<(sz-1):
            chain += x
        else:
            if  chain:
                if  len(chain)!=1:
                    off = len(w)-len(chain)-w.find(chain)
                    result += chr(len(chain)*4+off//256)+chr(off%256)
                    bits += [1]
                else:
                    result += chain
                    bits += [0]
                chain = ""
            if  x is not None:
                result += x
                bits += [0]
    if  len(bits)%8:
        result += chr(0)*(8-len(bits)%8)
    return "Z"+encode_bits(bits)+result

def encode_huff(bytes):
    def get_huff_table(bytes):
        table = {}
        for b in bytes:
            table[b] = 1 if not b in table else table[b]+1
        table = sorted([[k,v] for k,v in table.items()],key=lambda x:x[1])
        while len(table)>2:
            table = sorted(table[2:]+[[table[:2],table[0][1]+table[1][1]]],key=lambda x:x[1])
        return table
    def get_huff_codes(table,prefix=[]):
        res = []
        for i,it in enumerate(table):
            if  isinstance(it[0],basestring):
                res+=[(it[0],prefix+[i])]
            elif  isinstance(it[0],list):
                res+=get_huff_codes(it[0],prefix+[i])
        return res
    def canonize_huff_codes(codes):
        res = []
        code = []
        codes = sorted(codes,key=lambda x:(len(x[1]),x[0]))
        for c in codes:
#            print(c[0],len(c[1]),c[1])
            for i in range(1,len(code)+1):
                if  code[-i]==0:
                    code[-i]=1
                    break
                else:
                    code[-i]=0
            if  len(c[1])>len(code):
                code += [0]*(len(c[1])-len(code))
            res.append([c[0],[]+code])
        res = dict(res)
        for i in range(256):
            if  not chr(i) in res:
                res[chr(i)]=[]
        m = max([len(c) for c in res.values()])
        if  m>16:
            raise
        return res
    def encode_huff_codes(codes):
        return "C"+"".join([chr(len(codes[chr(2*i)])*16+len(codes[chr(2*i+1)])) for i in range(128)])

    codes = canonize_huff_codes(get_huff_codes(get_huff_table(bytes)))
    bits = []
    for i,b in enumerate(bytes):
        bits.extend(codes[b])
#    bits = sum((codes[b] for b in bytes),[])
    return "H"+encode_huff_codes(codes)+encode_bits(bits)

def encode_pak(*args):
    bytes = "P"
    for a in args:
        bytes += chr(len(a)//256)+chr(len(a)%256)+a
    bytes += chr(0)+chr(0)
    return bytes

def encode_dir(*args):
    bytes = "D"
    for a in args:
        n = "T"+a[0]
        bytes += chr(len(n)//256)+chr(len(n)%256)+n
        bytes += chr(len(a[1])//256)+chr(len(a[1])%256)+a[1]
    bytes += chr(0)+chr(0)
    return bytes

txt = open("res/clarke.txt","r").read()
w,h,r,c = decode_img("res/bestever.png")
d1=encode_huff(encode_dir(
    ("about",encode_dir(
        ("bin","B"+"This is a simple app for testing decompression algorithms."+"".join([chr(i) for i in range(256)])),
    )),
    ("names",encode_huff("T"+txt)),
    ("rle",encode_img(w,h,c,encode_rle(encode_raw(r)))),
))

w1,h1,r1,c1 = decode_img("res/cirno.png")
w2,h2,r2,c2 = decode_img("res/thread70.png")
w3,h3,r3,c3 = decode_img("res/marisa.png")
d2=encode_huff(encode_pak(
    encode_img(w1,h1,c1,encode_lz77(encode_raw(r1))),
    encode_img(w2,h2,c2,encode_huff(encode_rle(encode_raw(r2),mask=128))),
    encode_img(w3,h3,c3,encode_huff(encode_rle(encode_raw(r3),mask=128))),
    "TAll images are copyleft by Anonymous",
))

with open("out/world.map","wb") as f:
    f.write(chr(len(d1)//256)+chr(len(d1)%256))
    f.write(d1)
    f.write("L"*(0x4000-len(d1)-2))
    f.write(chr(len(d2)//256)+chr(len(d2)%256))
    f.write(d2)
    f.write("L"*(0x4000-len(d2)-130))

    