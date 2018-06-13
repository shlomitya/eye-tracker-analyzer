
% addpath('C:\Users\Owner\Documents\m-files\analysis\microsaccade_detection')
% addpath('C:\Users\Owner\Documents\m-files\analysis')
% addpath('C:\Users\Owner\Documents\m-files')
addpath(genpath('..\tools\'))
addpath(genpath(('..\useful_functions\')))
% addpath('C:\Program Files\MATLAB\R2014a\toolbox\eeglab13_5_4b\plugins\biosig\t200_FileAccess');
clear all
close all
sync_trigger_start=66;
sync_trigger_end=66;
to_parse=1;
% cd 'C:\Users\Noam\Google Drive\Studies\M.A\Thesis\Code\EEG + ET sync'
subjects=10;  %the numeric identifies for requested subjects E.G (subjects=[2 6 7 8 9 20])
for snum=subjects
      
    bdfname=['Ex6_S' num2str(snum) '.bdf'];
    edfname=['Ex6_S', num2str(snum) '.asc'];   %should be allready and .asc file, used with visual EDF2ASC converter
    
    %open EEGLAB
    [ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
    eeglab redraw
    %%  1. open bdf file
    current_location=pwd;
    fullpathbdf=[current_location,'\original bdfs','\',bdfname];
    EEG = pop_biosig(fullpathbdf);
    [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
    [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'gui','off');
    eeglab redraw
    %%  2. add location file
    EEG=pop_chanedit(EEG, 'load',{'..\tools\head72.locs' 'filetype' 'autodetect'});
    [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
    eeglab redraw
    %%  3. reference
%     EEG = pop_reref( EEG, 65,'keepref','on');
%     [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 1,'setname','nose refrenced','gui','off');
%     [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
%     eeglab redraw
    
    %%  4 parse ET
    fullpathedf=[current_location,'\edfs\',edfname];
    fullpathmat=[current_location,'\edfs\',edfname(1:end-3),'mat'];
    
    if to_parse
        ET = parseeyelink(fullpathedf,fullpathmat);   %unmark if this if the eye data isnt parsed yet
    end
    
    EEG = eeg_checkset( EEG );
    eeglab redraw
    %%  5 syncronize
    EEG = pop_importeyetracker(EEG,fullpathmat,[sync_trigger_start sync_trigger_end],[1:8] ,{'TIME' 'L_GAZE_X' 'L_GAZE_Y' 'L_AREA' 'R_GAZE_X' 'R_GAZE_Y' 'R_AREA' 'INPUT'},1,1,0,1);
    [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 2,'gui','off');
    eeglab redraw
    %% save syncronized dataset
    
    
    EEG = pop_saveset( EEG, 'filename',['subject_',num2str(snum) '_synced.set'],'filepath',[current_location,'\eeglab data sets\']);
end