function imgOut = snapshotCustom(w)
% snapshotCustom: clears the buffer and get latest frame
% INPUT: 
% w - webcam obj
%
% OUTPUT:
% imgOut - image data 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Buffer size
i = 5;
while(i>0)
    imgOut = snapshot(w);
    i = i -1;
end
end