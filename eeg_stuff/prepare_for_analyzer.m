%% find all different trigger types and names:
% addpath('C:\Program Files\MATLAB\R2014a\toolbox\eeglab13_5_4b\');
% addpath('C:\Users\OWNER\Desktop\backup\eeglab13_3_2b\plugins\biosig\t200_FileAccess')
clear all
close all

subjects=[10];   %:11,13:16,18:21];

export_bdf=1;
export_triggers=1;


for subject=subjects
    
    datasetsfolder=[pwd '\eeglab data sets\'];
    setname=['subject_' num2str(subject) '_ms_bool_chan_engbert_alg_conc_blocks.set'];
    [ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
    EEG = pop_loadset('filename',setname,'filepath',datasetsfolder);
    eeglab redraw
    
    if export_bdf
        pathname=[pwd,'\for analyzer\s' num2str(subject) ,'_synced_and_detected.bdf'];
        pop_writeeeg(EEG,pathname, 'TYPE','BDF');
    end
    
    
    %%check what kind of different triggers you have
    triggers={EEG.event(1).type};
    % triggers{2,1}=1;
    counter=2;
    for i=2:length(EEG.event)
        
        
        eventtype={EEG.event(i).type};
        if ~ismember(eventtype,triggers)
            triggers{1,counter}=EEG.event(i).type;
            %         triggers{2,counter}=1;
            counter=counter+1;
            %     else
        end
        
    end
    
    %show available events:
    triggers
    
    %recode events
    %event names
    
    triggernames={'R_fixation','L_fixation','R_saccade','L_saccade','saccade','rmsaccade','lmsaccade'};
    %requested numeric recording
    
    rename=[210,210,231,232,220,221,222];
    
    for i=1:length(EEG.event)
        newtrig=rename(strcmp(triggernames,EEG.event(i).type));
        if ~isempty(newtrig)
            EEG.event(i).type=newtrig;
        else
            EEG.event(i).type=str2num(EEG.event(i).type);
        end
    end
    
    
    if export_triggers
        
        current_folder=pwd;
        destination_folder=[current_folder,'\for analyzer\'];
        filename=['s' num2str(subject),'_events.csv'];
        pop_expevents(EEG, [destination_folder,filename], 'samples');
        
        %% opening the csv file:
        
        ftoread = [destination_folder,filename];
        fid = fopen(ftoread);
        fgetl(fid)
        f = fopen([destination_folder,filename(1:end-4),'.txt'], 'w','n','US-ASCII');
        fprintf(f, 'Sampling rate: 1024Hz, SamplingInterval: 0.9765625ms\n');
        fprintf(f, 'Type, Description, Position, Length, Channel\n');
        fprintf(f, 'New Segment, , 1, 1, All\n');
        fprintf(f, 'Comment, Start Epoch, 1, 1, All\n');
        fprintf(f, 'Comment, CMS in range, 1, 1, All\n');
        fprintf(f, 'Comment, ActiveTwo MK2, 1, 1, All\n');
        fprintf(f, 'Comment, Speed Mode 4, 1, 1, All\n');
        for i=1:length(EEG.event)
            line=['Stimulus, '] ;
            x=fgetl(fid); %insert the line into a variable
            deliminators=find(x=='.');
            stype=x(deliminators(1)+8:deliminators(2)-1);
            latency=x(deliminators(2)+8:deliminators(3)-1);
            line=[line,'S',stype,', ',latency,', 1, All'];
            fprintf(f, '%s\n',sprintf(line));
        end
        fclose(f);
    end
    
    disp 'Done.'
end

