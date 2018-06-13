function EEG=add_blink_chan(EEG,varargin)
%this function adds a blinks channel to segmented or unsegmented EEG data.
%EEG dataset must contain ET events in strings e.g. R_blink
%((DS must be after ET sync))
% Input must be either EEG data alone or EEG data with two blink edge
% deltas (in ms)
%
% 
% Rot Amit  Dekel Abeles
%Jun 2015.
if isempty(varargin)
delta1=200;
delta2=200;
else 
    delta1=varargin{1}
    delta2=varargin{2}
end   

segmented=length(size(EEG.data))>2;

if segmented

   sanity=1;
 
nchans=EEG.nbchan;
for i=1:length(EEG.epoch)
    seg=boolean(zeros(1,EEG.pnts));
    for j=1:length(EEG.epoch(i).event)
        if strcmp(EEG.epoch(i).eventtype(j),'R_blink') | strcmp(EEG.epoch(i).eventtype(j),'L_blink')
           blinkstart_sp= ms2samp(EEG.epoch(i).eventlatency{j}-1000*EEG.xmin,EEG.srate);
           blinksend_sp=blinkstart_sp+ms2samp(EEG.epoch(i).eventduration{j},EEG.srate);
           blinkstart_sp=blinkstart_sp-ms2samp(delta1,EEG.srate);
           blinksend_sp=blinksend_sp+ms2samp(delta2,EEG.srate);

           if blinkstart_sp<1
               blinkstart_sp=1;
           end
           if blinksend_sp>EEG.pnts
              blinksend_sp=EEG.pnts;
           end
           seg(blinkstart_sp:blinksend_sp)=1;
            EEG.data(nchans+1,:,i)=seg;
        end
    end
end

EEG.nbchan=EEG.nbchan+1; 
EEG.chanlocs(end+1).labels='blinks';
EEG.chanlocs(end).type='EYE';
if sanity
plot(EEG.times,EEG.data(74,:,2))
hold on
plot(EEG.times,EEG.data(EEG.nbchan,:,2)*1000,'r')
end

else
    
 
    
blinkstarts=[];blinkends=[];
for i=1:length(EEG.event)
    if strcmp(EEG.event(i).type,'R_blink') | strcmp(EEG.event(i).type,'L_blink')
        blinkstarts=[blinkstarts EEG.event(i).latency];
        blinkends=[blinkends EEG.event(i).latency+EEG.event(i).duration];
    end
end

blinksbool=boolean([zeros(1,EEG.pnts)]);%initialize array matching the time points

blinkends(blinkends>EEG.pnts)=EEG.pnts;

a=length(blinkstarts); %blink number (vector length)
for i =1:a
     blinksbool(blinkstarts(i)-delta1:blinkends(i)+delta2)=1;
     
end
EEG.data(end+1,:)=blinksbool;
EEG.chanlocs(end+1).labels='blinks';
EEG.chanlocs(end).type='EYE';
EEG.nbchan=EEG.nbchan+1;

end
eeglab redraw