% Get SaccadesSegWithBlinks.
%
%Purpose: activate Engbert's code on structure d
%INPUT: 
%d should be a matrix of timePointsX6.
%if "eyelink" is the struct created by "readEDF" then:
%d= [eyelink.gazeRight.time(1:end)' eyelink.gazeRight.x(1:end)'...
%    eyelink.gazeRight.y(1:end)' eyelink.gazeLeft.x(1:end)'...
%    eyelink.gazeLeft.y(1:end)' blinks_vector];
% blinks_vector should have 1 whenever there's a blink (take it out of the
% eyelink.blinks data structure).
%sampling is the sampling rate of the eye tracker (usually 500 or 1000)
%room : should be "lab" when running in our room. important: add the right parameters
%in GetMicroSacDataFunWithBlinks!!!!!!!

%%OUTPUT
%onset, offset, amplitude: the onsets, offsets and
%amplitudes of each saccade. The onsets and offsets are in timepoints, not
%in ms!!! If no saccade was found, the entry for this trial is zero

%Note:
%handles null points in d
%does not allow for two saccades within 50ms (dekel 12/2 - changed it so
%the difference is from offset to onset, and not onset to onset as it
%usually was)
%%%%%%%%%%%

%added angle information to functions the output (dekel abeles, 5/8/15)



function [onsets offsets amplitudes vels directions] = getSaccadesSegNoBlinks(d,sampling,room)

blink=squeeze(d(:,6));
d=d(:,1:5);


%includes Inds holds 1s when there no nan and 0 when there is nan
includeInds=ones(1,size(d,1));
includeInds(isnan(d(:,2)))=0;
includeInds(isnan(d(:,3)))=0;
includeInds(find(blink))=0;
keepInds=find(includeInds);
d_all=d;
%now d should contain only non-null data points
d=d(keepInds,:);

if ~exist('showplots','var')
    showplots = 0  ; % change to one for interactive
end
sac=[];
if ~isempty(keepInds)    
sac=GetMicroSacDataFunNoBlinks(sampling,d,room);
end
meansac = saccpar(sac); % get combined data from the two eyes (see sacpar help for details)
if size(sac,1)==0
    onsets=0;
    offsets=0;
    amplitudes=0;
    vels=0;
    directions=0;
   
else
meansac = saccpar(sac); % get combined data from the two eyes (see sacpar help for details)
onsets = meansac(:,1);
offsets = meansac(:,2);
directions=meansac(:,7); %can also be 9, which is a different estimating methods as i understand (dekel 05.08.15)
amplitudes = meansac(:,8);
vels = meansac(:,5);
end
if onsets~=0
 onsets=keepInds(onsets);
end
if offsets~=0
 offsets=keepInds(offsets);
end
if onsets==0
    onsets=[];
    offsets=[];
    amplitudes=[];
    vels=[];
    directions=[];
end
% if showplots
%     plot(d(:,1), d(:,2), 'b',d(:,1), d(:,3),'c' )
%     title([ 'Trial ' num2str(i) ': ' num2str(amplitude(i)) ])
%     hold on
%     
%     %mark all saccades with circles
%     plot(d(meansac(:,1),1), d(meansac(:,1),2),'ro')
%     plot(d(meansac(:,2),1), d(meansac(:,2),2),'go')
%     %mark the largest saccade with '*'
%     plot(d(onset(i),1), d(onset(i),2),'r*') %the maximum saccade on x
%     plot(d(offset(i),1), d(offset(i),2),'g*')
%     plot(d(onset(i),1), d(onset(i),3),'r*') %the maximum saccade on y
%     plot(d(offset(i),1), d(offset(i),3),'g*')
%     pause
% end

%allow only one saccades within 70ms
%get the largest saccades within this range
if length(onsets)>1
spoints=70*(sampling/1000);
donsets=diff(onsets);
%donsets=onsets(2:end)-offsets(1:end-1);
maxAmp=amplitudes(1);
inds=[];
iMaxInd=1;
i=2;
while i<=length(onsets)
if donsets(i-1)<spoints
    if amplitudes(i)>maxAmp 
        iMaxInd=i;
        maxAmp=amplitudes(i);
    end   
else %we finished scannign one saccade - add the maximum amplitude
    inds=[inds iMaxInd];
    iMaxInd=i;
    maxAmp=amplitudes(i);
end
i=i+1;
end
inds=[inds iMaxInd];
%take the last point of this saccade
onsets=onsets(inds);

amplitudes=amplitudes(inds);
vels=vels(inds);
directions=directions(inds);




%added by dekel 12/02/17
%go over the selected onsets, and pick the latest relevant offset to mark
%the saccade end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% figure(); 
% plot(d_all(:,2:5))
% hold on
% plot([onsets; onsets],repmat([0 2000],length(onsets),1)','r')
% hold on
% plot([offsets; offsets],repmat([0 2000],length(offsets),1)','g')
% hold on 
% plot(blink*1000);


%create an empty vector to mark the relevant offset indexes
offset_inds=[];
for i=1:length(onsets)-1
    %add find the latest offset for the current onset, that does not
    %exceeds the following onsets
    
    curr_indexes=find((onsets(i)<offsets & onsets(i+1)>offsets));
    curr_onset=onsets(i);
    curr_offsets=offsets(curr_indexes);
    suitable_ind=find((curr_offsets-curr_onset)<100,1,'last');
    wanted_inds=curr_indexes(suitable_ind);
    if isempty(wanted_inds);
        wanted_inds=curr_indexes(1);
    end
  offset_inds=[offset_inds,wanted_inds];
end
%add the last requested index:
offset_inds(end+1)=find(onsets(end)<offsets,1,'last');
offsets=offsets(offset_inds);
%offsets=offsets(inds)


%if a saccade started before a blink, and the algorithem marked its ending
%at the end of the blink, move that specific ending to the start of that
%blink

%calculate durations
durations=offsets-onsets;
%find implausible saccade durations
bad_durations=find(durations>200);
%find blink ends
blink_ends=find(diff(blink)==-1);
%find blink starts
blinks_starts=find(diff(blink)==1);

%go over the bad durations saccade, and change those saccade ending to the
%start of the blink interval (instead of its ending)
if~isempty(bad_durations) && ~isempty(blinks_starts)
%     cnt=0;
    for bd=bad_durations
        if bd>1
        blink_start_ind=find(blinks_starts<offsets(bd) & blinks_starts>offsets(bd-1),1,'last');
offsets(bd)=blinks_starts(blink_start_ind);
        else
        blink_start_ind=find(blinks_starts<offsets(bd),1,'last');
        offsets(bd)=blinks_starts(blink_start_ind);  
        end
    end
end

%make sure there are no saccades starting less than 20ms 
min_diff_end_to_start=20;
bad_ind=find((onsets(2:end)-offsets(1:end-1)<min_diff_end_to_start));

onsets(bad_ind+1)=[];
offsets(bad_ind)=[];
amplitudes(bad_ind)=[];
vels(bad_ind)=[];
directions(bad_ind)=[];

%make sure no saccade with duration less than 5ms
durations=offsets-onsets;
min_duration=5;
onsets=onsets(durations>=min_duration);
offsets=offsets(durations>=min_duration);
amplitudes=amplitudes(durations>=min_duration);
vels=vels(durations>=min_duration);
directions=directions(durations>=min_duration);




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%








end

        
