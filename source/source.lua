-- title:  Compression Sandbox
-- author: lb_ii
-- desc:   tiny viewer for packed resources, that supports chained grouping and packing with RLE/LZ77/Huffman code
-- script: lua

function UNPAK(b)
 local C,I,K,R,T,U=0,0,0,{},{},table.unpack
 trace(type(b)=="table" and b[1])
--MEM
 if type(b)=="number" then
	 for i=1,peek(b)*256+peek(b+1) do
   R[i]=peek(b+1+i)
		end
--Pak
	elseif b[1]==80 then
  R[0]="P"
  while 1 do
   I=I+K+2
   K=b[I]*256+b[I+1]
			if K==0 then break end
   R[#R+1]=UNPAK({U(b,I+2,I+K+2)})
		end
		return R
--Dir
 elseif b[1]==68 then
	 b[1]=80
		T=UNPAK(b)
  R[0]="D"
		for i=1,#T//2 do
   R[T[2*i-1][1]]=T[2*i]
		end
		return R
--Text
	elseif b[1]==84 then
  T=""
  for i=2,#b-1 do
		 T=T..string.char(b[i])
		end
	 return {[0]="T",T}
--Image
	elseif b[1]==73 then
	 K=6+b[5]*3
	 return {
		 [0]="I",
			b[2]+b[4]//16*256,
			b[3]+b[4]%16*256,
		 {U(b,6,K)},
			UNPAK({U(b,K)})
		}
--Bin
 elseif b[1]==66 then
		return {[0]="B",U(b,2)}
--RAW
 elseif b[1]==78 then
		return {U(b,2)}
--RLE
	elseif b[1]==82 then
		for c=1,b[2]*256+b[3] do
   C=b[4+c+I]
			K=b[5+c+I]-b[4]
			I=K>0 and I+1 or I
			K=K>0 and K or 1
   for k=1,K do R[#R+1]=C end
		end
--LZ77
	elseif b[1]==90 then
	 C=b[2]*65536+b[3]*256+b[4]
	 I=5+C//8
		for i=0,C-1 do
		 T=5+i//8
   if b[T]%2>0 then
 	  K=#R-b[I]%4*256-b[I+1]
		  for z=1,b[I]//4 do
		 	 R[#R+1]=R[K+z]
		 	end
		 	I=I+2
		 else
    R[#R+1],I=b[I],I+1
	 	end
	 	b[T]=b[T]//2
	 end
--Canonical Huffman Codebook
 elseif b[1]==67 then
	 for i=1,128 do
		 T[2*i-1]={2*i-2,b[1+i]//16}
		 T[2*i]={2*i-1,b[1+i]%16}
		end
		table.sort(T,function(a,b) return
		 a[2]==b[2] and a[1]<b[1] or a[2]<b[2]
		end)
  K={}
		for i=1,256 do
		 for j=0,#K-1 do
			 K[#K-j]=1-K[#K-j]
				if K[#K-j]>0 then break end
			end
		 while #K<T[i][2] do K[#K+1]=0 end
   I="";for i=1,#K do I=I..K[i] end
			R[I]=T[i][1]
		end
  return R
--Huffman Coding
	elseif b[1]==72 then
  T=UNPAK({U(b,2)})
		I=""
		C=b[131]*65536+b[132]*256+b[133]
		for i=0,C-1 do
		 K=134+i//8
			I=I..(b[K]%2)
   if T[I] then
			 R[#R+1]=T[I]
				I=""
			end
	 	b[K]=b[K]//2
	 end
--??
 else
	 trace("WTF is "..b[1])
	 return {}
	end
	return UNPAK(R)
end








function scanline(l)
 if IT[0]=="I" and 
	   (l>8 or not SHOW_TOP)
	then
  for i=1,#IT[3] do
   poke(0x3FC0+i-1,IT[3][i])
  end  
	end
end

function DRAW(r,x,y,x0,y0,w,h)
 local W,H=r[1]//2,r[2]
	for i=0,H*W-1 do
	 if x+i%W*2>=0 and x+i%W*2<240 and
		   y+i//W>=0 and y+i//W<136
		then
  	poke(120*(y+i//W)+x/2+i%W,r[4][i+1])
		end
	end
end








-- based on palette demo by Nesbox --

DB16 = "140c1c".."442434".."30346d"..
       "4e4a4e".."854c30".."346524"..
       "d04648".."757161".."597dce"..
       "d27d2c".."8595a1".."6daa2c"..
       "d2aa99".."6dc2ca".."dad45e"..
       "deeed6"
function UPD_PAL(pal,offset)
  local p = pal or DB16
  local o = offset or 0
  for i=1,#p,2 do
    local adr=0x3FC0+o*3+i//6*3+i//2%3
    poke(adr,tonumber(p:sub(i,i+1),16))
  end  
end






--DSK=0x8000
--RES=UNPAK(DSK)
DRIVES={{"A",0x8000},{"B",0xC000}}
PATH={}
Y=0
SHOW_TOP=true

function UPD_IT()
	if DSK then
 	PT="UNPAK("..DSK..")"
 	IT=RES
	else
 	PT="DRIVES"
 	IT={[0]="0"}
 end
	for i=1,#PATH do
	 if type(PATH[i])=="number" then
	  PT=PT.."["..(PATH[i]).."]"
	  IT=IT[PATH[i]]
  else
	  PT=PT.."[\""..PATH[i].."\"]"
 	 IT=IT[PATH[i]]
		end
	end
 if IT[0]=="D" then
  IT_KEYS={}
 	for k in pairs(IT) do
		 if k~=0 then
 		 table.insert(IT_KEYS,1,k)
			end
		end
		table.sort(IT_KEYS)
	end
 if IT[0]=="T" then
  IT_TXT={""}
		for i=1,#IT[1] do
		 if IT[1]:sub(i,i)=="\n" then
			 IT_TXT[#IT_TXT+1]=""
   elseif #IT_TXT[#IT_TXT]>38 then
			 IT_TXT[#IT_TXT]=IT_TXT[#IT_TXT]..IT[1]:sub(i,i)
			 x = IT_TXT[#IT_TXT]:match'.*() ' or 0
			 IT_TXT[#IT_TXT+1]=IT_TXT[#IT_TXT]:sub(x+1)
			 IT_TXT[#IT_TXT-1]=IT_TXT[#IT_TXT-1]:sub(1,x)
			else
			 IT_TXT[#IT_TXT]=IT_TXT[#IT_TXT]..IT[1]:sub(i,i)
   end
		end
	end
 if type(Y)=="string" then
 	for i=1,#IT_KEYS do
		 if IT_KEYS[i]==Y then Y=i end
		end
	end
end

function UI()
 function UI_LINE(c,t,x,y,tt,ttt,tttt)
  tt=tt or ""
  ttt=ttt or ""
  tttt=tttt or ""
 	spr(c,x,y,0)
	 print(t,x+10,y+2)
  print(tt,x+64,y+2)
  print(ttt,x+160,y+2)
  print(tttt,x+108,y+2)
 end

 function UI_ITEM(it,i,t)
	 if it[0]=="P" then
  	UI_LINE(0,t,10,10*i,"<pak>")
  elseif it[0]=="D" then
  	UI_LINE(0,t,10,10*i,"<dir>")
  elseif it[0]=="I" then
  	UI_LINE(3,t,10,10*i,"<img>",it[1].."x"..it[2])
  elseif it[0]=="T" then
  	UI_LINE(4,t,10,10*i,"<txt>",#it[1].." bytes")
  elseif it[0]=="B" then
  	UI_LINE(5,t,10,10*i,"<bin>",#it.." bytes")
  else
  	UI_LINE(2,t,10,10*i,"<err>",#it)
		end
 end

	cls(0)

 if IT[0]=="0" then
 	rect(0,10*Y+10,240,9,13)
		for i=1,#DRIVES do
		 L=peek(DRIVES[i][2])*256+peek(DRIVES[i][2]+1)
			
  	UI_LINE(6,DRIVES[i][1]..":",10,10*i,"<mnt>",L.." bytes",string.format("0x%04x",DRIVES[i][2]))
		end
 elseif IT[0]=="I" then
 	DRAW(IT,120-IT[1]//2,68-IT[2]//2)
 elseif IT[0]=="T" then
	 if #IT_TXT>13 then
   rect(0,10+Y*126/#IT_TXT,3,13*126/#IT_TXT,7)
		end
  for k=1,13 do
		 if k+Y>#IT_TXT then break end
  	print(IT_TXT[k+Y],8,10*k,15)
		end
 elseif IT[0]=="B" then
	 if #IT>13*8 then
   rect(0,10+Y*126/((#IT-1)//8),3,13*126/((#IT-1)//8),5)
		end
  for k=0,12 do
		 if k+Y>(#IT)//8 then break end
		 print(string.format("%04x:",k*8+Y*8),8,10*k+10,5)
   for i=0,7 do
			 c = IT[i+1+k*8+Y*8]
			 if c==nil then break end
   	print(string.format("%02x",c),38+16*i,10*k+10,11)
   	print(string.char(c),178+8*i,10*k+10,11)
 		end
		end
	elseif IT[0]=="P" then
 	rect(0,10*Y+10,240,9,13)
  UI_LINE(1,"..",10,10,"<pak>")
	 for i=1,#IT do
		 UI_ITEM(IT[i],i+1,i)
		end
	elseif IT[0]=="D" then
 	rect(0,10*Y+10,240,9,13)
  UI_LINE(1,"..",10,10,"<dir>")
	 for i=1,#IT_KEYS do
		 UI_ITEM(IT[IT_KEYS[i]],i+1,IT_KEYS[i])
		end
	end
 if SHOW_TOP then
 	rect(0,0,240,9,7)
 	UI_LINE(0,PT,2,0)
		if IT[0]=="I" then
   print(IT[1].."x"..IT[2],192,2)
		end
	end
end

function CONTROL_INNER(up,down,ok,esc)
 function NOT_LAST()
  return (IT[0]=="P" and Y<#IT) or
   (IT[0]=="0" and Y<#DRIVES-1) or
   (IT[0]=="D" and Y<#IT_KEYS) or
   (IT[0]=="B" and Y<#IT//8-12) or
   (IT[0]=="T" and Y<#IT_TXT-13)
 end

 if up and Y>0 then
	 Y=Y-1
	end

	if down and NOT_LAST() then
  Y=Y+1
 end

	if ok then
	 if IT[0]=="0" then
			DSK=DRIVES[Y+1][2]
   RES=UNPAK(DSK)
 		UPD_IT()
		 Y=0
	 elseif IT[0]=="P" and Y>0 then
   PATH[#PATH+1]=Y
   Y=0
		elseif IT[0]=="D" and Y>0 then
   PATH[#PATH+1]=IT_KEYS[Y]
   Y=0
  elseif Y==0 and
		       (IT[0]=="P" or IT[0]=="D")
		then
		 esc = true
		end
 end

	if esc then
  Y=0
	 if #PATH>0 then
   Y=table.remove(PATH,#PATH) or 0
 		UPD_IT()
		else
	  for i=1,#DRIVES do
	   if DRIVES[i][2]==DSK then Y=i-1 end
 		end
   DSK=nil
		end
	end
end

function CONTROL()
	if btnp(7) and IT[0]=="I" then
  SHOW_TOP=not SHOW_TOP
	end
	if SHOW_TOP then
  CONTROL_INNER(btnp(0,20,1),btnp(1,20,1),btnp(3),btnp(2))
	end
end

function TIC()
 UPD_PAL()
 UPD_IT()
	UI()
	CONTROL()
end

