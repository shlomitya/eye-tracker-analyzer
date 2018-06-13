function [ newx,newy ] = correct_eyepos( x,y,p )
%This function corrects the eye position reported by Eyelink to take into
%account the effect of pupil size over recorded position. 

% INPUT: three column vectors x,y,p where x is x position, y is y position,
% and p is pupil size. 

% OUTPUT - corrected x and y positions. 
% Roy Amit, Feb 2017
if size(p,2)>1
    p=p';
end
if size(x,2)>1
    x=x';
end
if size(y,2)>1
    y=y';
end

if any(isnan(x))|any(isnan(y))|any(isnan(p))
    disp('cant work with nans')
    newx=x;newy=y;
    return
end

b=polyfit(p,x,1);
predictedx=(p)*b(1);
newx=x-(predictedx-mean(predictedx));

b=polyfit(p,y,1);
predictedx=(p)*b(1);
newy=y-(predictedx-mean(predictedx));


end

