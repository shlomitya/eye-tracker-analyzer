
%this codes recieved syncronized data (EEG and EDF) it will concatinate the
%blocks, detect missing information (that is not captured by the blink
%channel) and will let engbert algoritm to detect it (while ignoring blinks
%and missing data). it will then add a boolean channel of saccade and
%saccades events to the EEG structure - this should be the final step
%before exporting the bdf and trigger list (can be done with
%prepare_for_analyzer.m).

% addpath('C:\Users\Owner\Google Drive\useful_functions\general analysis')
% addpath('C:\Users\Owner\Documents\m-files\analysis\microsaccade_detection')
% addpath('C:\Users\Owner\Documents\m-files\analysis')
% addpath('C:\Users\Owner\Documents\m-files')
% addpath('C:\Users\Owner\Google Drive\useful_functions\general analysis')
% addpath(genpath(('C:\Users\Owner\Google Drive\useful_functions\')))

% cd 'C:\Users\Noam\Google Drive\Studies\M.A\Thesis\Code\EEG + ET sync';
clear all
close all

subjects=[10];
for subject=subjects
    
    [ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
    current_location=pwd
    filepath=[current_location,'\test folder\'];
    filename=['subject_' num2str(subject),'_synced.set'];
    
    EEG = pop_loadset('filename',filename,'filepath',filepath);
    eeglab redraw
    %add a blink channel
    EEG=add_blink_chan_200(EEG);  %should be fixed, not working good enough, maybe eyelink blink detection sucks...
    eeglab redraw
    %add an empty bool channel
    EEG.data(end+1,:)=boolean(zeros(1,length(EEG.times)));
    EEG.nbchan=EEG.nbchan+1;
    EEG.chanlocs(EEG.nbchan)=EEG.chanlocs(EEG.nbchan-1);
    
    %rename it
    EEG.chanlocs(EEG.nbchan).labels='sac onset bool';
    eeglab redraw        
    
    %%find block starts and end
    blockstarts=[];
    blockends=[];
    
    
    for i=1:length(EEG.event)
        if  strcmp('8', EEG.event(i).type)
            blockstarts=[blockstarts,EEG.event(i).latency];
        elseif strcmp('9', EEG.event(i).type)
            blockends=[blockends,EEG.event(i).latency];
        end
    end
    
    if length(blockends)~=length(blockstarts)
        blockamounts=min(length(blockends),length(blockstarts));
        blockends=blockends(1:blockamounts);
        blockstarts=blockstarts(1:blockamounts);
    end
    
    
    LH=[];
    LV=[];
    RH=[];
    RV=[];
    blinksvec=[];
    concatinated_block_starts=1;
    missingdatavector=zeros(1,length(EEG.times)) ;
    for i=1:length(blockstarts)
        sindex=blockstarts(i);
        eindex=blockends(i);
        blockduration=eindex-sindex;
        %create a vector containing the starttime of each block in the concatinated
        %structure
        concatinated_block_starts(i+1)=concatinated_block_starts(i)+blockduration;
        LH=[LH,EEG.data(74,sindex:eindex)];
        LV=[LV,EEG.data(75,sindex:eindex)];
        RH=[RH,EEG.data(77,sindex:eindex)];
        RV=[RV,EEG.data(78,sindex:eindex)];
        blinkdata=EEG.data(81,sindex:eindex);
        blinkdata(1:200)=1;
        blinksvec=[blinksvec,blinkdata];
        blinksvec(end-200:end)=1;
    end
    blinksvec=blinksvec(1:length(RH));
    
    
    %make sure to mark as blinks also the places where EEG lab extrapolated the
    %nans in the data:
    clear differences
    differences(:,1)=diff(LH);
    differences(:,2)=diff(RH);
    
    counter_limit=50; %defnine how many consequetive samples are defined as missing data and will be placed with "blinks" into the algo
    
    strikebreak_lim=5; %how many consequetive samples with different slopes are needed to break the counter*
    
    newblinksvec=zeros(1,length(LH)); %blinksvec;
    
    samediffcounter=0;
    dif_diff_counter=0;
    flatliners_indexes=[];
    for i=1:(size(differences,1)-1);
        %if the slopes are equal in two consecuative samples (its currently
        %still in pixels, so the differences should be quite big)
        if abs((differences(i,1)-differences(i+1,1)))<abs(0.01) || abs((differences(i,2)-differences(i+1,2)))<abs(0.01)
            
            samediffcounter=samediffcounter+1;
            dif_diff_counter=0;
        else    %two consequative sapmles are different
            dif_diff_counter=dif_diff_counter+1 ;
        end
        
        if samediffcounter>=counter_limit
            flatliners_indexes=[flatliners_indexes,i];
            newblinksvec(i-(samediffcounter-1):i)=1;
        end
        
        if dif_diff_counter>=strikebreak_lim
            samediffcounter=0;
            dif_diff_counter=0;
        end
        
        if mod(i,100000) == 0
            disp(['current index ' num2str(i)]);
        end
        
    end
    
    
    % %% check the detection of blinks
    % timeaxis=1:length(LH);
    % flatindexes=find(diff(flatliners_indexes)>10)
    % figure
    % plot(timeaxis,LV,'r')
    % hold on
    % plot(timeaxis(flatliners_indexes(flatindexes)),LV(flatliners_indexes(flatindexes)),'or')
    % hold on
    % plot(timeaxis,RV,'b')
    % hold on
    % plot(timeaxis(flatliners_indexes(flatindexes)),RV(flatliners_indexes(flatindexes)),'go')
    %
    % hold on
    % plot(timeaxis,newblinksvec*500,'m')
    % hold on
    % plot(timeaxis,blinksvec*400,'g')
    % title('blinks detection in the concatinated blocks');
    %
    % legend('LV','detected_blink','RV','detected blink','new blinks vector','old blinks vector')
    
    %% add +- add_to_blink samples;
    add_to_blink=200; %amount to add in MS to the blink (before and after);
    final_blinks_vector=newblinksvec;
    
    blink_starts_ends=find(diff(newblinksvec)~=0);
    for blinks=blink_starts_ends(1:2:end)
        if blinks>add_to_blink
            final_blinks_vector(blinks-add_to_blink:blinks)=1;
        end
    end
    
    datasize=length(newblinksvec);
    for blinke=blink_starts_ends(2:2:end)
        if blinke+add_to_blink<datasize
            final_blinks_vector(blinke:blinke+add_to_blink)=1;
        end
    end
    
    %% recheck the detection of blinks with the additional size:
    %% check the detection of blinks
    timeaxis=1:length(LH);
    flatindexes=find(diff(flatliners_indexes)>10);
    figure
    plot(timeaxis,LV,'r')
    hold on
    plot(timeaxis(flatliners_indexes(flatindexes)),LV(flatliners_indexes(flatindexes)),'or')
    hold on
    plot(timeaxis,RV,'b')
    hold on
    plot(timeaxis(flatliners_indexes(flatindexes)),RV(flatliners_indexes(flatindexes)),'go')
    
    hold on
    plot(timeaxis,final_blinks_vector*500,'m')
    hold on
    plot(timeaxis,blinksvec*400,'g')
    title('blinks detection in the concatinated blocks');
    
    legend('LV','detected_blink','RV','detected blink','new blinks vector','old blinks vector')
    
    
    %%prepare data to sacs_extract, EEGlab automaticly extrapolate the nulls,
    %%but now with final_blinks_vec, i can use it to recreate those nulls, so i
    %%can use sacs_extract as usuall, i just need to place nans inplaces of
    %%blinks.
    
    final_blinks_vector=logical(final_blinks_vector);
    LH(final_blinks_vector)=nan;
    LV(final_blinks_vector)=nan;
    RH(final_blinks_vector)=nan;
    LV(final_blinks_vector)=nan;
    
    
    
    %detect saccade from concatinated blocks
    [allsacps]=sacs_extract_concatinated_blocks(LH,LV,RH,RV,final_blinks_vector,1,[]);
    h=figure('Name',['subject ' num2str(subject),'detection check']);
    timeaxis=1:length(RH);
    hold all
    plot(timeaxis,LH,'b')
    plot(timeaxis,LV,'b')
    plot(timeaxis,RH,'g')
    plot(timeaxis,RV,'g')
    plot(timeaxis(allsacps(:,1)),LH(allsacps(:,1)),'or')
    legend('L_eye_x','L_eye_y','R_eye_x','R_eye_y','sacs');
    title('detected saccades in concatenated blocked data')
    
    %fix the timings to fit to the original EEG structure
    EEG_starttimes=[];
    EEG_endtimes=[];
    for sac=1:size(allsacps,1)
        block=find(allsacps(sac,1)>concatinated_block_starts,1,'last');
        EEG_starttimes(sac)=allsacps(sac,1)-concatinated_block_starts(block)+blockstarts(block)-1*block;
        EEG_endtimes(sac)=allsacps(sac,2)-concatinated_block_starts(block)+blockstarts(block)-1*block;
    end
        
    h=figure; hold all
    plot(EEG.times,EEG.data(74,:),'b')
    plot(EEG.times,EEG.data(75,:),'b')
    plot(EEG.times,EEG.data(77,:),'g')
    plot(EEG.times,EEG.data(78,:),'g')
    plot(EEG.times,EEG.data(81,:),'m')
    plot(EEG.times(EEG_starttimes(:)),EEG.data(74,EEG_starttimes),'or')
    legend('L_eye_x','L_eye_y','R_eye_x','R_eye_y','blinks(old vector)','saccades');
    for l=1:length(blockstarts)
        plot([EEG.times(blockstarts(l)),EEG.times(blockstarts(l)),EEG.times(blockends(l)),EEG.times(blockends(l))],[0 1500 1500 0],'m','Linewidth',2)
    end
    title('saccades detection on entire data')
    
    
    
    %allsacps: onsets(k),offsets(k),amplitudes(k),vels(k),deltax,deltay
    
    h1=figure;
    subplot(1,3,3);
    rose(atan2(allsacps(:,6),allsacps(:,5)))
    title('directions')
    subplot(1,3,1);
    scatter(log(allsacps(:,3)),log(allsacps(:,4)))
    subplot(1,3,2);
    hist(allsacps(:,3),100)
    title('amplitudes')
    
    savefig(h1,[current_location,'\figures\','subject' num2str(subject) 'saccade_parameters.fig'])
    save([pwd,'\saccade paramaters\s',num2str(subject),'_saccades_paramaters.mat'],'allsacps')
    
    
    amp_limit=2; %in degrees
    amp_limit=amp_limit*60; %in pixels
    %%add the boolean channel and events to EEG structure
    for i=2:length(allsacps)
        
        %update the micro_saccade boolean channel
        if allsacps(i,3)<amp_limit
            EEG.data(82,EEG_starttimes(i))=1;
        end
        
        %check for directionality
        
        if abs(atan2(allsacps(i,6),allsacps(i,5)))>=pi/2   %if its a left saccade
            eventname='lmsaccade';
        else
            eventname='rmsaccade';
        end
        
        if allsacps(i,3)>amp_limit
            eventname='saccade';
        end
        
        %build the event structure with required info
        EEG.event(end+1).type=eventname;
        EEG.event(end).latency=EEG_starttimes(i);
        EEG.event(end).duration=EEG_endtimes(i)-EEG_starttimes(i);
        EEG.event(end).endtime=EEG_endtimes(i);
        EEG.event(end).sac_amplitude=allsacps(i,3);        
    end
    
    %% double check the boolean
    h=figure; hold all
    plot(EEG.times,EEG.data(74,:),'b')
    plot(EEG.times,EEG.data(75,:),'b')
    plot(EEG.times,EEG.data(77,:),'g')
    plot(EEG.times,EEG.data(78,:),'g')
    plot(EEG.times,EEG.data(81,:)*1200,'k')
    plot(EEG.times,EEG.data(82,:)*1000,'c')
    for l=1:length(blockstarts)
        plot([EEG.times(blockstarts(l)),EEG.times(blockstarts(l)),EEG.times(blockends(l)),EEG.times(blockends(l))],[0 1500 1500 0],'m','Linewidth',2)
    end
    legend('L_eye_x','L_eye_y','R_eye_x','R_eye_y','blinks(old vector)','saccades');
    savefig(h,[current_location,'\figures\','subject' num2str(subject) 'eye_detection_quality_check_eeg.fig'])
    
    
    
    %% export the new final dataset:
    EEG = pop_saveset( EEG, 'filename',['subject_',num2str(subject) '_ms_bool_chan_engbert_alg_conc_blocks.set'],'filepath',[current_location,'\eeglab data sets\']);
    
    disp 'Done'
end



