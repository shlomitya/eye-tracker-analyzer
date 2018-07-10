classdef EyeTrackerAnalysisRecord < handle
    properties (Access= public, Constant)
        CONDS_NAMES_PREFIX= 'c';
    end
    
    properties (Access= private, Constant)
        READ_EDF_PATH= fullfile('readEDF'); 
        PUPILS_BASED_BLINKS_DETECTION_STD = 2.5;
        PUPILS_BASED_BLINKS_DETECTION_CONSECUTIVE_SAMPLES = 3;
        PUPILS_BASED_BLINKS_DETECTION_TOLERANCE = 3;
        PUPILS_BASED_BLINKS_DETECTION_MAX_SEG_TIME = 10;
    end
    
    properties (Access= private)          
        analysis_tag;
        eye_tracker_data_structs;
        is_eeg_involved;
        segmentization_vecs_index= {};
        segmentization_vecs= {};
        saccades_extractors_data= {};
        chosen_segmentization_i= 0;
        progress_screen;  
        dpp = [];
        sampling_rate = [];
    end
    
    methods (Access= public)
        function obj= EyeTrackerAnalysisRecord(progress_screen, progress_contribution, analysis_tag, eye_tracker_files, dpp)             
            obj.analysis_tag= analysis_tag; 
            obj.dpp = dpp;          
            curr_path= pwd;            
            if ~iscell(eye_tracker_files)
                eye_tracker_files= {eye_tracker_files};
            end
            eye_tracker_files_nr= numel(eye_tracker_files);
            obj.is_eeg_involved= false;
            obj.eye_tracker_data_structs= {};            
            for eye_tracker_file_i= 1:eye_tracker_files_nr                 
                curr_eye_tracker_full_file_name= eye_tracker_files{eye_tracker_file_i};
                [~, eye_tracker_file_name, eye_tracker_file_ext]= fileparts(curr_eye_tracker_full_file_name);                                    
                if strcmp(eye_tracker_file_ext, '.edf')                    
                    copyfile(curr_eye_tracker_full_file_name, EyeTrackerAnalysisRecord.READ_EDF_PATH);
                    progress_screen.displayMessage(['converting session #', num2str(eye_tracker_file_i), ' edf file']);
                    cd(EyeTrackerAnalysisRecord.READ_EDF_PATH);
                    extracted_struct = readEDF([eye_tracker_file_name, '.edf']);
                    extracted_struct = rmfield(extracted_struct, 'fixations');
                    extracted_struct = rmfield(extracted_struct, 'saccades');
                    extracted_struct.gazeLeft = rmfield(extracted_struct.gazeLeft, 'pix2degX');
                    extracted_struct.gazeLeft = rmfield(extracted_struct.gazeLeft, 'pix2degY');
                    extracted_struct.gazeLeft = rmfield(extracted_struct.gazeLeft, 'velocityX');
                    extracted_struct.gazeLeft = rmfield(extracted_struct.gazeLeft, 'velocityY');
                    extracted_struct.gazeLeft = rmfield(extracted_struct.gazeLeft, 'whichEye');
                    extracted_struct.gazeRight = rmfield(extracted_struct.gazeRight, 'pix2degX');
                    extracted_struct.gazeRight = rmfield(extracted_struct.gazeRight, 'pix2degY');
                    extracted_struct.gazeRight = rmfield(extracted_struct.gazeRight, 'velocityX');
                    extracted_struct.gazeRight = rmfield(extracted_struct.gazeRight, 'velocityY');
                    extracted_struct.gazeRight = rmfield(extracted_struct.gazeRight, 'whichEye');
                    extracted_structs = {extracted_struct};
                    delete([eye_tracker_file_name, '.edf']);
                    cd(curr_path);                  
                elseif strcmp(eye_tracker_file_ext, '.mat')
                    progress_screen.displayMessage(['loading session #', num2str(eye_tracker_file_i), ' mat file']);
                    loaded_mat= load(curr_eye_tracker_full_file_name);
                    extracted_structs = EyeTrackerAnalysisRecord.extractEyeTrackerStructsFromLoadedMatStructs(loaded_mat);                    
                    if isempty(extracted_structs)                        
                        error('EyeTrackerAnalysisRecord:InvalidMat', [eye_tracker_file_name, '.mat does not contain an eyelink data struct.']);                                    
                    end                    
                elseif strcmp(eye_tracker_file_ext, '.set')                    
                    extracted_structs = {EyeTrackerAnalysisRecord.addEtaFieldsToEegStruct(pop_loadset(curr_eye_tracker_full_file_name))};                    
                    obj.is_eeg_involved= true;
                end                                
                
                if eye_tracker_file_i == 1
                    obj.sampling_rate = 1000 / (extracted_structs{1}.gazeRight.time(2) - extracted_structs{1}.gazeRight.time(1));
                else   
                    for session_i = 1:numel(extracted_structs)
                        curr_session_sampling_rate = 1000 / (extracted_structs{session_i}.gazeRight.time(2) - extracted_structs{session_i}.gazeRight.time(1));
                        if curr_session_sampling_rate ~= obj.sampling_rate
                            error('EyeTrackerAnalysisRecord:InvalidMat', [eye_tracker_file_name, 'contains data with different sampling rate (', num2str(curr_session_sampling_rate), ' Hz) than does the first session file (', num2str(obj.sampling_rate), ' Hz) - sessions with different sampling rates are not supported.']);                    
                        end
                    end
                end
                
                % reformat messages and inputs structure arrays
%                 extracted_structs_nr = numel(extracted_structs);
%                 for struct_i = 1:extracted_structs_nr
%                     extracted_structs{struct_i}.messages_orig = extracted_structs{struct_i}.messages;
%                     extracted_structs{struct_i}.messages = [];
%                     extracted_structs{struct_i}.messages.message = {};
%                     extracted_structs{struct_i}.messages.time = [];
%                     msgs_nr = numel(extracted_structs{struct_i}.messages_orig);
%                     msgs_nr_per_progress_interval = min(200, msgs_nr);
%                     progress_intervals_nr = floor(msgs_nr/msgs_nr_per_progress_interval);
%                     for msg_i = 1:msgs_nr
%                         extracted_structs{struct_i}.messages.message = ...
%                             [extracted_structs{struct_i}.messages.message, extracted_structs{struct_i}.messages_orig(msg_i).message];
%                         extracted_structs{struct_i}.messages.time = ...
%                             [extracted_structs{struct_i}.messages.time, extracted_structs{struct_i}.messages_orig(msg_i).time];
%                         if mod(msg_i, msgs_nr_per_progress_interval) == 0
%                             progress_screen.addProgress(0.5*progress_contribution/(eye_tracker_files_nr*extracted_structs_nr*progress_intervals_nr));
%                         end
%                     end                    
%                     extracted_structs{struct_i} = rmfield(extracted_structs{struct_i}, 'messages_orig');
%                     
%                     extracted_structs{struct_i}.inputs_orig = extracted_structs{struct_i}.inputs;
%                     extracted_structs{struct_i}.inputs = [];
%                     extracted_structs{struct_i}.inputs.input = [];
%                     extracted_structs{struct_i}.inputs.time = [];
%                     inputs_nr = numel(extracted_structs{struct_i}.inputs_orig);
%                     inputs_nr_per_progress_interval = min(200, inputs_nr);
%                     progress_intervals_nr = floor(inputs_nr/inputs_nr_per_progress_interval);
%                     for input_i = 1:inputs_nr
%                         extracted_structs{struct_i}.inputs.input = ...
%                             [extracted_structs{struct_i}.inputs.input, extracted_structs{struct_i}.inputs_orig(input_i).input];
%                         extracted_structs{struct_i}.inputs.time = ...
%                             [extracted_structs{struct_i}.inputs.time, extracted_structs{struct_i}.inputs_orig(input_i).time];
%                         
%                         if mod(input_i, msgs_nr_per_progress_interval) == 0
%                             progress_screen.addProgress(0.5*progress_contribution/(eye_tracker_files_nr*extracted_structs_nr*progress_intervals_nr));
%                         end
%                     end
%                     extracted_structs{struct_i} = rmfield(extracted_structs{struct_i}, 'inputs_orig');                     
%                 end                

                progress_screen.addProgress(progress_contribution/eye_tracker_files_nr);
                obj.eye_tracker_data_structs= [obj.eye_tracker_data_structs, extracted_structs];                  
            end                         
        end                
                  
        function was_previous_segmentization_loaded= segmentizeData(obj, progress_screen, progress_contribution, trial_onset_triggers, trial_offset_triggers, trial_rejection_triggers, baseline, post_offset_triggers_segment, trial_dur, blinks_delta)
            segmentizations_nr= numel(obj.segmentization_vecs);            
            for segmentization_i= 1:segmentizations_nr
                if isempty( setxor(obj.segmentization_vecs_index{segmentization_i, 1}, trial_onset_triggers) ) && ...
                        obj.segmentization_vecs_index{segmentization_i, 2} == trial_dur && ...
                        obj.segmentization_vecs_index{segmentization_i, 3} == baseline && ...
                        obj.segmentization_vecs_index{segmentization_i, 4} == blinks_delta && ...
                        isempty( setxor(obj.segmentization_vecs_index{segmentization_i, 5}, trial_offset_triggers) ) && ...
                        ( isempty(obj.segmentization_vecs_index{segmentization_i, 6}) && isempty(post_offset_triggers_segment) || ...
                          ~isempty(obj.segmentization_vecs_index{segmentization_i, 6}) && ~isempty(post_offset_triggers_segment) && obj.segmentization_vecs_index{segmentization_i, 6} == post_offset_triggers_segment ) && ...
                        isempty( setxor(obj.segmentization_vecs_index{segmentization_i, 7}, trial_rejection_triggers) )  
                      
                    obj.chosen_segmentization_i= segmentization_i;                    
                    was_previous_segmentization_loaded= true;
                    progress_screen.addProgress(progress_contribution);
                    return;
                end
            end
            
            was_previous_segmentization_loaded = false;
            sessions_nr = numel(obj.eye_tracker_data_structs);            
            for session_i= 1:sessions_nr
                curr_session_eye_tracker_data_struct= obj.eye_tracker_data_structs{session_i};                                                               
                progress_screen.displayMessage(['session #', num2str(session_i), ': indexing blinks']);
                eyelink_based_blinks_vec = EyeTrackerAnalysisRecord.eyelinkBased_blinkdetection(curr_session_eye_tracker_data_struct, blinks_delta, progress_screen, 0.8*progress_contribution/sessions_nr); %0.4*progress_contribution/sessions_nr);
                pupils_based_blinks_vec = EyeTrackerAnalysisRecord.pupilBased_blinkdetection_twoEyes(curr_session_eye_tracker_data_struct.gazeRight.pupil, curr_session_eye_tracker_data_struct.gazeLeft.pupil, obj.sampling_rate, obj.PUPILS_BASED_BLINKS_DETECTION_STD, obj.PUPILS_BASED_BLINKS_DETECTION_CONSECUTIVE_SAMPLES, obj.PUPILS_BASED_BLINKS_DETECTION_TOLERANCE, blinks_delta, obj.PUPILS_BASED_BLINKS_DETECTION_MAX_SEG_TIME, progress_screen, 0); %0.4*progress_contribution/sessions_nr);
                obj.segmentization_vecs{segmentizations_nr+1}(session_i).blinks= eyelink_based_blinks_vec | pupils_based_blinks_vec;                
                triggers_nr= numel(trial_onset_triggers);                
                for trigger_i= 1:triggers_nr                    
                    progress_screen.displayMessage(['session #', num2str(session_i), ': segmentizing data by condition ', trial_onset_triggers{trigger_i}]);
                    if all(isstrprop(trial_onset_triggers{trigger_i},'digit'))                                                
                        curr_cond_field_name = [obj.CONDS_NAMES_PREFIX, trial_onset_triggers{trigger_i}];
                        [start_times, end_times] = extractSegmentsTimesFromInputs(curr_session_eye_tracker_data_struct, str2double(trial_onset_triggers{trigger_i}));
                        if numel(start_times)==0
                            [start_times, end_times] = extractSegmentsTimesFromMessages(curr_session_eye_tracker_data_struct, trial_onset_triggers{trigger_i});
                        end
                    else                                                
                        curr_cond_field_name = convertMsgToValidFieldName(trial_onset_triggers{trigger_i});                                                
                        [start_times, end_times] = extractSegmentsTimesFromMessages(curr_session_eye_tracker_data_struct, trial_onset_triggers{trigger_i});                                                
                    end

                    if numel(start_times)==0
                        obj.segmentization_vecs{segmentizations_nr+1}(session_i).trials_start_times.(curr_cond_field_name)= [];
                        obj.segmentization_vecs{segmentizations_nr+1}(session_i).trials_end_times.(curr_cond_field_name)= [];
                        progress_screen.displayMessage(['session #', num2str(session_i), ':Didn''t find trigger ', '''', trial_onset_triggers{trigger_i}, '''']);
                        progress_screen.addProgress(0.2*progress_contribution/(sessions_nr*triggers_nr));
                        continue;
                    end                                                           
                    
                    %assign trials timings 
                    trials_nr= numel(start_times);
                    obj.segmentization_vecs{segmentizations_nr+1}(session_i).trials_start_times.(curr_cond_field_name)= NaN(trials_nr, 1);
                    obj.segmentization_vecs{segmentizations_nr+1}(session_i).trials_end_times.(curr_cond_field_name)= NaN(trials_nr, 1);
                    session_samples_nr = numel(curr_session_eye_tracker_data_struct.gazeLeft.time);
                    for trial_i=1:trials_nr                          
                        indStart= find(ismember(curr_session_eye_tracker_data_struct.gazeLeft.time, start_times(trial_i) + (0 : (1000/obj.sampling_rate - 1))), 1);
                        if isempty(indStart)
                            continue;
                        end
                        if ~isempty(trial_offset_triggers)   
                            indEnd = find(ismember(curr_session_eye_tracker_data_struct.gazeLeft.time, end_times(trial_i) + (0 : (1000/obj.sampling_rate - 1))), 1);
                            if isempty(indEnd)
                                continue;
                            end
                        else
                            indEnd = indStart + min(ceil(trial_dur/(1000/obj.sampling_rate)) - 1, session_samples_nr - indStart);
                        end
                        
                        obj.segmentization_vecs{segmentizations_nr+1}(session_i).trials_start_times.(curr_cond_field_name)(trial_i) = indStart;
                        obj.segmentization_vecs{segmentizations_nr+1}(session_i).trials_end_times.(curr_cond_field_name)(trial_i) = indEnd;
                    end 
                    
                    progress_screen.addProgress(0.2*progress_contribution/(sessions_nr*triggers_nr));
                end 
            end                        
        
            obj.segmentization_vecs_index{segmentizations_nr+1, 1}= trial_onset_triggers;
            obj.segmentization_vecs_index{segmentizations_nr+1, 2}= trial_dur;
            obj.segmentization_vecs_index{segmentizations_nr+1, 3}= baseline;
            obj.segmentization_vecs_index{segmentizations_nr+1, 4}= blinks_delta;
            obj.segmentization_vecs_index{segmentizations_nr+1, 5}= trial_offset_triggers;
            obj.segmentization_vecs_index{segmentizations_nr+1, 6}= post_offset_triggers_segment;
            obj.segmentization_vecs_index{segmentizations_nr+1, 7}= trial_rejection_triggers;
            
            obj.saccades_extractors_data{segmentizations_nr+1}= [];
            obj.chosen_segmentization_i= numel(obj.segmentization_vecs);
            
            function msg = convertMsgToValidFieldName(msg)
                msg(ismember(msg,' -')) = '_';                
                if isstrprop(msg(1),'digit')
                    msg = [obj.CONDS_NAMES_PREFIX, msg];
                end                
            end
            
            function [start_times, end_times] = extractSegmentsTimesFromMessages(eye, trial_onset_trigger)
                % search phases:
                % 1 - trial onset
                % 2 - trial offset
                are_offset_triggers_included = ~isempty(trial_offset_triggers);
                start_times= []; 
                end_times = [];
                field_i = 1;                
                search_phase = 1;
                while field_i <= numel(eye.messages)                    
                    msg = eye.messages(field_i).message;
                    if isempty(msg)
                        field_i = field_i + 1;
                        continue;
                    end
                    
                    msg_time = eye.messages(field_i).time;
                    if search_phase == 1
                        if strcmp(msg, trial_onset_trigger)                            
                            potential_trial_start_time = msg_time;
                            search_phase = 2;
                        end                        
                    elseif (are_offset_triggers_included && (any(cellfun(@(str) strcmp(str, msg), trial_offset_triggers)) || msg_time - potential_trial_start_time > trial_dur - baseline)) || ...
                           (~are_offset_triggers_included && (any(cellfun(@(str) strcmp(str, msg), trial_onset_triggers)) || msg_time - potential_trial_start_time > trial_dur - baseline))
                        search_phase = 1;
                        start_times= [start_times, potential_trial_start_time - baseline]; %#ok<AGROW>
                        if are_offset_triggers_included
                            end_times = [end_times, msg_time + post_offset_triggers_segment]; %#ok<AGROW>                                                                        
                        else
                             continue;
                        end
                    elseif any(cellfun(@(str) strcmp(str, msg), trial_rejection_triggers))
                        search_phase = 1;
                    end
                    
                    field_i = field_i + 1;
                end
                
                if search_phase == 2
                    start_times= [start_times, potential_trial_start_time - baseline];
                    if are_offset_triggers_included
                        end_times = [end_times, potential_trial_start_time + trial_dur + post_offset_triggers_segment];
                    end
                end
            end                                      
            
            function [start_times, end_times] = extractSegmentsTimesFromInputs(eye, trial_onset_trigger)
                % search phases:
                % 1 - trial onset
                % 2 - trial offset
                are_offset_triggers_included = ~isempty(trial_offset_triggers);
                start_times= []; 
                end_times = [];
                field_i = 1;                
                search_phase = 1;
                while field_i <= numel(eye.inputs)                    
                    input = eye.inputs(field_i).input;
                    if isempty(input)
                        field_i = field_i + 1;
                        continue;
                    end
                    
                    input_time = eye.inputs(field_i).time;
                    if search_phase == 1
                        if input == trial_onset_trigger                            
                            potential_trial_start_time = input_time;
                            search_phase = 2;
                        end
                    elseif (are_offset_triggers_included && (any(cellfun(@(trigger) input == str2num(trigger), trial_offset_triggers)) || input_time - potential_trial_start_time > trial_dur - baseline)) || ...
                           (~are_offset_triggers_included && (any(cellfun(@(trigger) input == str2num(trigger), trial_onset_triggers)) || input_time - potential_trial_start_time > trial_dur - baseline))                       
                        search_phase = 1;
                        start_times= [start_times, potential_trial_start_time - baseline]; %#ok<AGROW>
                        if are_offset_triggers_included
                            end_times = [end_times, input_time + post_offset_triggers_segment]; %#ok<AGROW>                                                                        
                        else
                             continue;
                        end
                    elseif any(cellfun(@(input) str2double(input) == eye.inputs(field_i).input, trial_rejection_triggers))
                        search_phase = 1;
                    end
                    
                    field_i = field_i + 1;
                end  
                
                if search_phase == 2
                    start_times= [start_times, potential_trial_start_time - baseline];
                    if are_offset_triggers_included
                        end_times = [end_times, potential_trial_start_time + trial_dur + post_offset_triggers_segment];
                    end
                end
            end                                
        end
        
        function segmentized_data= getSegmentizedData(obj, filter_bandpass)
            if obj.chosen_segmentization_i==0
                error('EyeTrackerAnalysisRecord:noSegmentizationChosen', 'must call segmentizeData() prior to getSegmentizedData() so segmentized data would be chosen/created');                
            end
                        
            sessions_nr= numel(obj.segmentization_vecs{obj.chosen_segmentization_i});
            segmentized_data_unmerged= cell(1,sessions_nr);
            for session_i= 1:sessions_nr                
                curr_session_segmentization_vecs_struct= obj.segmentization_vecs{obj.chosen_segmentization_i}(session_i);
                curr_session_eye_tracker_data_struct= EyeTrackerAnalysisRecord.filterEyeData(obj.eye_tracker_data_structs{session_i}, filter_bandpass, obj.sampling_rate);
                conds_names= fieldnames(curr_session_segmentization_vecs_struct.trials_start_times);                
                for cond_name_i= 1:numel(conds_names)
                    curr_cond_name= conds_names{cond_name_i}; 
                    trials_nr= numel(curr_session_segmentization_vecs_struct.trials_start_times.(curr_cond_name));
                    if trials_nr==0
                        segmentized_data_unmerged{session_i}.(curr_cond_name)= [];
                    else
                        for trial_i= 1:trials_nr
                            indStart= curr_session_segmentization_vecs_struct.trials_start_times.(curr_cond_name)(trial_i);
                            if isnan(indStart)
                                segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).onset_from_session_start= [];
                                segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).samples_nr= [];
                                segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).blinks= [];                                
                                segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).gazeLeft= [];
                                segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).gazeRight= [];                                
                                continue;
                            end
                            segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).onset_from_session_start= indStart;
                            indEnd= curr_session_segmentization_vecs_struct.trials_end_times.(curr_cond_name)(trial_i);
                            segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).samples_nr= indEnd - indStart + 1;
                            segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).blinks= curr_session_segmentization_vecs_struct.blinks(indStart:indEnd);                             
                            
                            %if only one eye was recorded save everything to both gazeRight and gazeLeft
                            if obj.eye_tracker_data_structs{session_i}.gazeRight.x(1)<-30000 || obj.eye_tracker_data_structs{session_i}.gazeLeft.x(1)<-30000
                                if curr_session_eye_tracker_data_struct.gazeLeft.x(1)>-30000
                                    gaze= curr_session_eye_tracker_data_struct.gazeLeft;
                                else
                                    gaze= curr_session_eye_tracker_data_struct.gazeRight;
                                end
                                                                
                                segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).gazeRight.x= gaze.x(indStart:indEnd);
                                segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).gazeRight.y= gaze.y(indStart:indEnd);
                                segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).gazeRight.pupil= gaze.pupil(indStart:indEnd);                                 
                                segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).gazeLeft.x= segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).gazeRight.x;
                                segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).gazeLeft.y= segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).gazeRight.y;
                                segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).gazeLeft.pupil= segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).gazeRight.pupil;
                            else                                                            
                                segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).gazeLeft.x= curr_session_eye_tracker_data_struct.gazeLeft.x(indStart:indEnd);
                                segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).gazeLeft.y= curr_session_eye_tracker_data_struct.gazeLeft.y(indStart:indEnd);
                                segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).gazeLeft.pupil= curr_session_eye_tracker_data_struct.gazeLeft.pupil(indStart:indEnd);
                                segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).gazeRight.x= curr_session_eye_tracker_data_struct.gazeRight.x(indStart:indEnd);
                                segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).gazeRight.y= curr_session_eye_tracker_data_struct.gazeRight.y(indStart:indEnd);
                                segmentized_data_unmerged{session_i}.(curr_cond_name)(trial_i).gazeRight.pupil= curr_session_eye_tracker_data_struct.gazeRight.pupil(indStart:indEnd);
                            end
                        end
                    end
                end
            end
            
            %merge sessions' structs                        
            if sessions_nr>1                
                conds_names= fieldnames(obj.segmentization_vecs{obj.chosen_segmentization_i}(1).trials_start_times);            
                for cond_i= 1:numel(conds_names)     
                    curr_merged_cond_name= conds_names{cond_i};
                    segmentized_data.(curr_merged_cond_name)= [];
                    for merged_session_i= 1:sessions_nr                                                                                                           
                        if ~isempty(segmentized_data_unmerged{merged_session_i}.(curr_merged_cond_name))
                            segmentized_data.(curr_merged_cond_name)= ...
                                [segmentized_data.(curr_merged_cond_name), segmentized_data_unmerged{merged_session_i}.(curr_merged_cond_name)];                        
                        end
                    end
                end                                                  
            else
                segmentized_data= segmentized_data_unmerged{1};                
            end                              
        end
                
        function registerSaccadesAnalysis(obj, saccades_analysis_struct)
            if obj.chosen_segmentization_i==0
                error('EyeTrackerAnalysisRecord:noSegmentizationChosen', 'data of an EyeTrackerAnalysisRecord object has to be segmentized prior to analysis');                
            end
                       
            obj.saccades_extractors_data{obj.chosen_segmentization_i}= saccades_analysis_struct;
        end
        
        function saccades_analysis_struct= loadSaccadesAnalysis(obj)
            if obj.chosen_segmentization_i==0
                error('EyeTrackerAnalysisRecord:noSegmentizationChosen', 'data of an EyeTrackerAnalysisRecord object has to be segmentized prior to analysis');                
            end                        
            
            saccades_analysis_struct= obj.saccades_extractors_data{obj.chosen_segmentization_i};
        end
        
        function analysis_tag= getAnalysisTag(obj)
            analysis_tag= obj.analysis_tag;
        end  
        
        function eye_tracker_data_structs= getEyeTrackerDataStructs(obj)
            eye_tracker_data_structs= obj.eye_tracker_data_structs;
        end
        
        function dpp = getDpp(obj)
            dpp = obj.dpp;
        end
        
        function sampling_rate = getSamplingRate(obj)
            sampling_rate = obj.sampling_rate;
        end
        
        function save(obj, full_file_path)                                                                  
            eta = obj; %#ok<NASGU>
        	tic; save(full_file_path, 'eta', '-mat'); toc;
        end
        
        function is_eeg_involved= isEegInvolved(obj)
            is_eeg_involved= obj.is_eeg_involved;
        end
    end
    
    methods (Access= private, Static)                    
        function eye_tracking_data_structs= extractEyeTrackerStructsFromLoadedMatStructs(loaded_struct)
            eye_tracking_data_structs= {};
            fields_names= fieldnames(loaded_struct);
            for field_i= 1:numel(fields_names)
                curr_tested_variable= loaded_struct.(fields_names{field_i});
                if isstruct(curr_tested_variable)
                    %if isStructAnEyeDataStruct(curr_tested_variable)
                        eye_tracking_data_structs= [eye_tracking_data_structs, curr_tested_variable]; %#ok<AGROW>
                    %end
                elseif iscell(curr_tested_variable)                 
                    for slot_i= 1:numel(curr_tested_variable)
                        %if isStructAnEyeDataStruct(curr_tested_variable{slot_i})
                            eye_tracking_data_structs= [eye_tracking_data_structs, curr_tested_variable{slot_i}]; %#ok<AGROW>                         
                        %end
                    end                   
                end
            end
                                     
            function res= isStructAnEyeDataStruct(struct)
                if numel(fieldnames(struct))~= 12 || ...
                        ~isfield(struct, 'filename') || ...
                        ~isfield(struct, 'numElements') || ...
                        ~isfield(struct, 'numTrials') || ...
                        ~isfield(struct, 'EDFAPI') || ...
                        ~isfield(struct, 'preamble') || ...
                        ~isfield(struct, 'gazeLeft') || ...
                        ~isfield(struct, 'gazeRight') || ...                       
                        ~isfield(struct, 'blinks') || ...
                        ~isfield(struct, 'messages') || ...
                        ~isfield(struct, 'gazeCoords') || ...
                        ~isfield(struct, 'frameRate') || ...
                        ~isfield(struct, 'inputs')
                    res= false;
                    return;
                end
                
                if ~isValidGazeStruct(struct.gazeLeft)  || ~isValidGazeStruct(struct.gazeRight)
                    res= false;
                    return;
                end                                                                
                
                blinks_struct= struct.blinks;
                if numel(fieldnames(blinks_struct))~= 2 || ...
                        ~isfield(blinks_struct, 'startTime') || ...
                        ~isfield(blinks_struct, 'endTime')
                    res= false;
                    return;
                end
                
                if isempty(struct.messages)  || ...
                        numel(fieldnames(struct.messages))~=2 || ...
                        ~isfield(struct.messages, 'message') || ...
                        ~isfield(struct.messages, 'time')
                    res= false;
                    return;
                end
                
                if isempty(struct.inputs)  || ...
                        numel(fieldnames(struct.inputs))~=2 || ...
                        ~isfield(struct.inputs, 'input') || ...
                        ~isfield(struct.inputs, 'time')
                    res= false;
                    return;
                end
                
                res= true;
                % === TYPES CHECK NOT INCLUDED ===
                %         if ~ischar(struct.filename) || ...
                %            ~isnumeric(struct.numElements) || ...
                %            numel(struct.numElements)~=1 || ...
                %            ~isnumeric(struct.numTrials) || ...
                %            numel(struct.numTrials)~=1 || ...
                %            ~ischar(struct.EDFAPI) || ...
                %            ~ischar(struct.preamble) || ...
                %            ~isnumeric(struct.gazeCoords) || ...
                %            numel(struct.gazeCoords)~=4 || ...
                %            ~isnumeric(struct.frameRate) || ...
                %            numel(struct.frameRate)~=1
                %             res= false;
                %             return;
                %         end
                function res= isValidGazeStruct(struct)
                    if numel(fieldnames(struct))~= 4 || ...
                            ~isfield(struct, 'time') || ...
                            ~isfield(struct, 'x') || ...
                            ~isfield(struct, 'y') || ...
                            ~isfield(struct, 'pupil')
                        res= false;
                    else
                        res= true;
                    end
                end
            end
        end
        
        function updated_eeg_struct= addEtaFieldsToEegStruct(eeg_struct)          
            updated_eeg_struct= eeg_struct;
            updated_eeg_struct.gazeLeft.x= double(eeg_struct.data(74,:));
            updated_eeg_struct.gazeLeft.y= double(eeg_struct.data(75,:));
            updated_eeg_struct.gazeLeft.pupil= double(eeg_struct.data(76,:));
            updated_eeg_struct.gazeLeft.time= 1:numel(updated_eeg_struct.gazeLeft.x);
            updated_eeg_struct.gazeRight.x= double(eeg_struct.data(77,:));
            updated_eeg_struct.gazeRight.y= double(eeg_struct.data(78,:));
            updated_eeg_struct.gazeRight.pupil= double(eeg_struct.data(79,:));
            updated_eeg_struct.gazeRight.time= 1:numel(updated_eeg_struct.gazeRight.x);
                                    
            for trigger_i= 1:numel(eeg_struct.event)                                
                updated_eeg_struct.messages(trigger_i).time= eeg_struct.event(trigger_i).latency;
                updated_eeg_struct.messages(trigger_i).message= eeg_struct.event(trigger_i).type;
                updated_eeg_struct.inputs(trigger_i).time= [];
                updated_eeg_struct.inputs(trigger_i).input= [];
            end
            
            updated_eeg_struct.blinks.startTime= [];
            updated_eeg_struct.blinks.endTime= [];
            for event_i= 1:numel(eeg_struct.event)
                if strcmp(eeg_struct.event(event_i).type,'R_blink') || strcmp(eeg_struct.event(event_i).type,'L_blink')
                    updated_eeg_struct.blinks.startTime= [updated_eeg_struct.blinks.startTime, eeg_struct.event(event_i).latency];
                    updated_eeg_struct.blinks.endTime= [updated_eeg_struct.blinks.endTime, eeg_struct.event(event_i).latency + eeg_struct.event(event_i).duration];
                end
            end            
        end
            
        function eye_data_struct= filterEyeData(eye_data_struct, bandpass, rate)            
            eye_data_struct.gazeRight.x= EyeTrackerAnalysisRecord.naninterp(eye_data_struct.gazeRight.x);
            eye_data_struct.gazeRight.y= EyeTrackerAnalysisRecord.naninterp(eye_data_struct.gazeRight.y);
            eye_data_struct.gazeRight.x= EyeTrackerAnalysisRecord.lowPassFilter(bandpass,eye_data_struct.gazeRight.x,rate); %<<<=== rate ???
            eye_data_struct.gazeRight.y= EyeTrackerAnalysisRecord.lowPassFilter(bandpass,eye_data_struct.gazeRight.y,rate); %<<<=== rate ???
            eye_data_struct.gazeLeft.x= EyeTrackerAnalysisRecord.naninterp(eye_data_struct.gazeLeft.x);
            eye_data_struct.gazeLeft.y= EyeTrackerAnalysisRecord.naninterp(eye_data_struct.gazeLeft.y);
            eye_data_struct.gazeLeft.x= EyeTrackerAnalysisRecord.lowPassFilter(bandpass,eye_data_struct.gazeLeft.x,rate); %<<<=== rate ???
            eye_data_struct.gazeLeft.y= EyeTrackerAnalysisRecord.lowPassFilter(bandpass,eye_data_struct.gazeLeft.y,rate); %<<<=== rate ???                                                        
        end
                        
        function blinksbool= eyelinkBased_blinkdetection(eyelink, delta, progress_screen, progress_contribution)
            if nargin==1
                delta=130;
            end

            exp_time= length(eyelink.gazeRight.time);
            blinksbool= zeros(1, exp_time);%initialize array matching the time points
            blinksbool=boolean(blinksbool);
            blinks_nr= length(eyelink.blinks.startTime);
            
            interval_blinks_nr= min(200,blinks_nr);
            interval_progress_contribution= progress_contribution*interval_blinks_nr/blinks_nr;
            for i= 1:blinks_nr
                if mod(i,interval_blinks_nr)==0
                    progress_screen.addProgress(interval_progress_contribution);
                end

                curr_start_time_i= find(eyelink.gazeRight.time==eyelink.blinks.startTime(i), 1);
                curr_end_time_i= find(eyelink.gazeRight.time==eyelink.blinks.endTime(i), 1);
                if curr_start_time_i-delta<1
                    curr_start_time_i= 1;
                else
                    curr_start_time_i= curr_start_time_i - delta;
                end

                if curr_end_time_i+delta>exp_time
                    curr_end_time_i= exp_time;
                else
                    curr_end_time_i= curr_end_time_i + delta;
                end

                blinksbool(curr_start_time_i:curr_end_time_i)=1;     
            end 
            
            if mod(blinks_nr,interval_blinks_nr)~=0
                progress_screen.addProgress(progress_contribution*mod(1,interval_blinks_nr/blinks_nr));
            end
        end 
        
        function new_blink_vec=pupilBased_blinkdetection_twoEyes(pupilr, pupill, Fs, std, consq_samples, tolerance, padding, maxsegtime, progress_screen, progress_contribution)
            %% inputs
            % pupilr - the  pupildata vector of the right eye as retried by eyelink
            % (arbitrary units).
            % pupill - the  pupildata vector of the left eye as retried by eyelink
            % (arbitrary units).
            % Fs - the eye tracking sampling rate (not using this at the moment
            % 2.7.2018 (the hard coded numbers assumes a 1k refresh rate
            % std - how many stds from the mean define an outlier
            % consq_samples - how many consequtive outlier samples is the minimum to
            % consider an offset/onset candidnate
            % tolerance - how many non oulier samples will break the consequtive
            % outlier sample counter
            % old_blinkvec - a blink vector to plot and compare the new detection with.
            % to_plot - boolean if the user wants the trial to be plotted.
            % padding - how many samples to add before and after each detected blink.
            % maxsegtime -(in seconds) define the maximum size of segments per detection - this is
            % mainly important in non segmented data, as we use mean and std so
            % splitting the data makes sense to not get heart much by breaks and other
            % problems.
            new_blink_vecr=[];
            new_blink_vecl=[];
            new_blink_vec=[];
            segments_errors=[];
            % if data is long (over 10k samples) split it and then analyze smaller parts
            if (length(pupilr)/(maxsegtime*Fs))>1
                lastseg_size=rem(length(pupilr),(maxsegtime*Fs));                
                if lastseg_size>(maxsegtime*Fs/2)
                    starttimes=1:(maxsegtime*Fs):length(pupilr);
                else
                    starttimes=1:(maxsegtime*Fs):length(pupilr);
                    starttimes=starttimes(1:(end-1));
                end
                
                for i=1:length(starttimes)                    
                    if ~(i==length(starttimes));  %if it is not the last segment:
                        cur_pupilr=pupilr(starttimes(i):starttimes(i+1)-1);
                        cur_pupill=pupill(starttimes(i):starttimes(i+1)-1);                   
                    else
                        cur_pupilr=pupilr(starttimes(i):end);
                        cur_pupill=pupill(starttimes(i):end);                        
                    end
                    [blink_vecr,problemflagr]=EyeTrackerAnalysisRecord.pupilBased_blinkdetection(cur_pupilr,Fs,std,consq_samples,tolerance, progress_screen, 0.5*progress_contribution/length(starttimes));
                    [blink_vecl,problemflagl]=EyeTrackerAnalysisRecord.pupilBased_blinkdetection(cur_pupill,Fs,std,consq_samples,tolerance, progress_screen, 0.5*progress_contribution/length(starttimes));
                    
                    new_blink_vecr=[new_blink_vecr,blink_vecr];
                    new_blink_vecl=[new_blink_vecl,blink_vecl];
                    segments_errors=[segments_errors,problemflagr | problemflagl];                    
                end                
            else
                [new_blink_vecr,problemflagr]=EyeTrackerAnalysisRecord.pupilBased_blinkdetection(pupilr,Fs,std,consq_samples,tolerance, progress_screen, 0.5*progress_contribution);
                [new_blink_vecl,problemflagl]=EyeTrackerAnalysisRecord.pupilBased_blinkdetection(pupill,Fs,std,consq_samples,tolerance, progress_screen, 0.5*progress_contribution);
                segments_errors=[problemflagr | problemflagl];
            end
            
            %% count blinks only from both eyes:
            new_blink_vec=new_blink_vecr & new_blink_vecl;
            
            %% add the requested blink padding:
            onsets=find(diff(new_blink_vec)==1);
            offsets=find(diff(new_blink_vec)==-1);            
            temp_blink_vec=new_blink_vec;            
            for curroffset=offsets
                if (curroffset+padding)<=length(temp_blink_vec);
                    temp_blink_vec(curroffset:(curroffset+padding))=1;
                elseif curroffset<=length(temp_blink_vec);
                    temp_blink_vec(curroffset:(curroffset+(length(temp_blink_vec)-curroffset)))=1;
                end
            end
            
            for curronset=onsets
                if curronset-padding>0
                    temp_blink_vec(curronset-padding:curronset)=1;
                else
                    temp_blink_vec(1:curronset)=1;
                end
            end
            
            new_blink_vec=temp_blink_vec;            
        end
        
        function [blink_vec,problemflag]=pupilBased_blinkdetection(pupildata,Fs,std,consq_samples,tolerance, progress_screen, progress_contribution)
            % this functions uses the derivetive of pupilsize to find unplausible size
            % changes and mark them as blink onsets and offsets. %it then compares the
            % found blink with a prior blink vector.
            
            % in our lab settings, room a: the values that works for me are:
            % pupilBased_blinkdetection(pupildata,1000,2.5,4,5,old_blinkvec,1)
            
            %logic:
            %1. find all outlier samples in pupilsize slops (negative for onsets
            %and position for offsets)
            %2. search for consequtive outlier samples to define an offset or offset
            %3. correct end and start estimation by:
            %3.1 for onsets, go backwards on a filtered version of the pupilsize from
            %each onset untill the first non negative slope sample
            %3.2 for offsets, go forward from each offset and find the first non
            %positive slope sample
            
            %% inputs
            % pupildata - the  pupildata vector of one eye as retried by eyelink
            % (arbitrary units).
            % Fs - the eye tracking sampling rate (not using this at the moment
            % 2.7.2018 (the hard coded numbers assumes a 1k refresh rate
            % std - how many stds from the mean define an outlier
            % consq_samples - how many consequtive outlier samples is the minimum to
            % consider an offset/onset candidnate
            % tolerance - how many non oulier samples will break the consequtive
            % outlier sample counter
            % old_blinkvec - a blink vector to plot and compare the new detection with.
            % to_plot - boolean if the user wants the trial to be plotted.
            
            %% code: onests:
            %create a pupil size slope vector:
            slopes=diff(pupildata);
            slopes_zscores=(slopes-nanmean(slopes))./nanstd(slopes);
            
            
            %filter the data so i can follow the slope without gigsaw patterns.
            %first make sure it doenst end or starts with a nan or else
            %extrapolation will not work.
            if isnan(pupildata(end))
                pupildata(end)=nanmean(pupildata);
            end
            
            if isnan(pupildata(1))
                pupildata(1)=nanmean(pupildata);
            end
            
            %keep the original raw vector
            original_pupildata=pupildata;
            %create a boolean vector of nan values: to fix samples that are
            %sournded by nans
            temp_pupildata=zeros(1,length(pupildata));
            temp_pupildata(isnan(pupildata))=1;
                        
            %this code runs over the nan values and marks as nan every segment that
            %is too short (10 samples atm) and has a nan value before and after it.            
            valid_cnt=0;
            for i=2:length(temp_pupildata)-1;
                if temp_pupildata(i)==0
                    valid_cnt=valid_cnt+1;
                else
                    if valid_cnt<10
                        pupildata(i-valid_cnt:i-1)=nan;
                        valid_cnt=0;
                    else
                        valid_cnt=0;
                    end
                end
            end
                                    
            %filter the slopes: optional - causes some problems
            %     slopes=diff(pupildataclean);
            %
            %     %try filtering the slopes: (not sure);
            %     filtered_slopes=lowPassFilter(10,slopes,Fs);
            %     filtered_slopes_extrapolated=filtered_slopes;
            %     filtered_slopes(isnan(pupildata))=nan;
            %     slopes=filtered_slopes;
            %     slopes_zscores=(slopes-nanmean(slopes))./nanstd(slopes);                        
            if any(~isnan(slopes))                
                pupildataclean= EyeTrackerAnalysisRecord.naninterp(pupildata);                
                problemflag=0;  %will rise this flag to signal that non alternating onsets and offsets were found                                
                %suspect onsets:
                suspect_onsets_indexes=find(slopes_zscores<-1*std);
                %refine samples:
                real_onsets=[];                                
                if ~isempty(suspect_onsets_indexes)
                    cur_index=suspect_onsets_indexes(1);
                    cnt=1;                    
                    for i=2:length(suspect_onsets_indexes);                        
                        if ismember(suspect_onsets_indexes(i),cur_index:cur_index+tolerance)
                            cnt=cnt+1;
                            cur_index=suspect_onsets_indexes(i);
                        elseif cnt>=consq_samples;
                            
                            real_onsets=[real_onsets,suspect_onsets_indexes(i-1)-cnt];
                            cnt=0;
                            cur_index=suspect_onsets_indexes(i);
                        else
                            cnt=0;
                            cur_index=suspect_onsets_indexes(i);
                        end                                                                        
                    end
                    
                    %add the last onset:
                    if cnt>=consq_samples
                        real_onsets=[real_onsets,suspect_onsets_indexes(i-1)-cnt];
                        cnt=0;
                    end                                        
                end
                                                
                %% code:offsets:
                %create a pupil size slope vector:
                slopes=diff(pupildata);
                slopes_zscores=-1*(slopes-nanmean(slopes))./nanstd(slopes);                                
                %     slopes=diff(pupildataclean);
                %
                %     %try filtering the slopes: (not sure);
                %     filtered_slopes=lowPassFilter(10,slopes,Fs);
                %     filtered_slopes_extrapolated=filtered_slopes;
                %     filtered_slopes(isnan(pupildata))=nan;
                %     slopes=filtered_slopes;
                %     slopes_zscores=-1*(slopes-nanmean(slopes))./nanstd(slopes);
                
                %suspect offsets:
                suspect_offsets_indexes=find(slopes_zscores<-1*std);
                %refine samples:
                real_offsets=[];
                if ~isempty(suspect_offsets_indexes)
                    cur_index=suspect_offsets_indexes(1);
                    cnt=1;
                    
                    for i=2:length(suspect_offsets_indexes);
                        if ismember(suspect_offsets_indexes(i),cur_index:cur_index+5)
                            cnt=cnt+1;
                            cur_index=suspect_offsets_indexes(i);
                        elseif cnt>=consq_samples;
                            
                            real_offsets=[real_offsets,suspect_offsets_indexes(i-1)];
                            cnt=0;
                            cur_index=suspect_offsets_indexes(i);
                        else
                            cur_index=suspect_offsets_indexes(i);
                            cnt=0;
                        end                                                                        
                    end
                    
                    %add the last onset:
                    if cnt>=consq_samples
                        real_offsets=[real_offsets,suspect_offsets_indexes(i-1)-cnt];
                    end                                        
                end
                
                %% initial testing graph:
                %     if to_plot
                %
                %     figure();
                %     subplot(2,1,1);
                %     plot(pupildata); hold on;
                %     plot(suspect_onsets_indexes,pupildata(suspect_onsets_indexes),'*m');
                %     hold on;
                %     plot(suspect_offsets_indexes,pupildata(suspect_offsets_indexes),'*g');
                %     legend({'pupil','onsets','offsets'});
                %     end                                
                %% fix the onset timings (use ronen's method, of going backwards untill we find a non-negative slope
                final_onsets=[];
                %filter the raw pupil to have smooth curves:
                filtered_pupil=EyeTrackerAnalysisRecord.lowPassFilter(10,pupildataclean,Fs);
                filtered_pupil_extrapolated=filtered_pupil;
                filtered_pupil(isnan(pupildata))=nan;
                
                slopes=diff(filtered_pupil);
                
                cur_onset=[];
                for i=1:length(real_onsets);
                    stop=0;
                    cur_onset=real_onsets(i);
                    temp_onset=real_onsets(i);
                    while ~stop && cur_onset>1
                        cur_onset=cur_onset-1;
                        if slopes(cur_onset)<=0
                            temp_onset=cur_onset;
                        else
                            stop=1;
                            final_onsets=[final_onsets,temp_onset];
                        end
                    end
                    
                    if cur_onset==1;
                        final_onsets=[final_onsets,temp_onset];
                    end
                end
                                
                %% fix the offset timings:                
                final_offsets=[];
                slopes=diff(filtered_pupil);                
                arraysize=length(slopes);                
                cur_offset=[];
                for i=1:length(real_offsets);
                    stop=0;
                    cur_offset=real_offsets(i);
                    temp_offset=real_offsets(i);
                    while ~stop && cur_offset<arraysize
                        cur_offset=cur_offset+1;
                        if slopes(cur_offset)>=0
                            temp_offset=cur_offset;
                        else
                            stop=1;
                            final_offsets=[final_offsets,temp_offset+1];
                        end
                    end
                end
                
                if cur_offset==arraysize
                    final_offsets=[final_offsets,temp_offset];
                end
                                
                %% check for undetected onsets or offsets:                
                types=[zeros(1,length(final_onsets)),ones(1,length(final_offsets))];
                % 0 - is onset time
                % 1 is offset time
                alltimings=[final_onsets,final_offsets];
                %sort by timing:
                [sorted_timing,sorting_indexes]=sort(alltimings,'ascend');
                %sort the types:
                sorted_types=types(sorting_indexes);
                
                % incase double entrees were found, fix it by removing them from timing.                
                bad_timings=find(diff(sorted_timing)==0);
                sorted_types(bad_timings)=[];
                sorted_timing(bad_timings)=[];
                
                %find for problems (differences of 0)
                types_differences=diff(sorted_types);
                suspect_indexes=find(types_differences==0);
                blink_vec=zeros(1,length(pupildata));                
                first_offset_flag=0;                
                stop_fixing=0;
                run_cnt=0;
                                
                %% fix non alternative detected events:
                while ~stop_fixing
                    run_cnt=run_cnt+1;
                    current_bad_sample=find(diff(sorted_types)==0,1,'first');
                    if isempty(current_bad_sample) %if none exists, exit the loop
                        stop_fixing=1;
                    else   %there are consequtive events of the same type (either 2 onsets in a row or 2 offsets in a row)
                        curtype=sorted_types(current_bad_sample);                        
                        if curtype==0; %if its an onset, find an offset                            
                            curtime=sorted_timing(current_bad_sample);
                            next_event_time=sorted_timing(current_bad_sample+1);                            
                            cur_relevant_segment=filtered_pupil_extrapolated(curtime:next_event_time-1);
                            %first_negative sample after onset:
                            first_neg=find(diff(cur_relevant_segment)<0,1,'first');                            
                            if isempty(first_neg)
                                first_neg=1;
                            end
                            
                            %find the first positive after the negative:
                            first_pos=find(diff(cur_relevant_segment(first_neg:end))>=0,1,'first');                            
                            if isempty(first_pos)
                                first_pos=floor(length(cur_relevant_segment(first_neg:end))/2);
                            end
                            
                            %find the first negative after that pos:
                            offset_sample=find(diff(cur_relevant_segment((first_neg+first_pos+1):end))<0,1,'first');                            
                            if isempty(offset_sample)
                                offset_sample=length(cur_relevant_segment((first_neg+first_pos+1):end));
                            end
                                                        
                            cur_offset=curtime+first_neg+first_pos+offset_sample-1;                            
                            if isnan(filtered_pupil(cur_offset)); %if the found offset/onset is an extrapolated filtered sample it might be distroted by the filter
                                %thus i will go further forward untill i find the first non nan sample:
                                valid_offset_time=find(~isnan(filtered_pupil(cur_offset:next_event_time-1)),1,'first');
                                if isempty(valid_offset_time) %if none was found, remove the onset from the array
                                    sorted_timing(current_bad_sample)=[];
                                    sorted_types(current_bad_sample)=[];
                                else
                                    valid_offset_time=cur_offset+valid_offset_time;
                                    %add the new found offset:
                                    index_in_array=find(valid_offset_time<sorted_timing,1,'first');
                                    sorted_timing=[sorted_timing(1: index_in_array-1),valid_offset_time,(sorted_timing(index_in_array:end))];
                                    sorted_types=[sorted_types(1: index_in_array-1),1,(sorted_types(index_in_array:end))];
                                    final_offsets=[final_offsets,valid_offset_time];
                                end
                            else                                                                
                                %add the new found offset:
                                index_in_array=find(cur_offset<sorted_timing,1,'first');
                                sorted_timing=[sorted_timing(1: index_in_array-1),cur_offset,(sorted_timing(index_in_array:end))];
                                sorted_types=[sorted_types(1: index_in_array-1),1,(sorted_types(index_in_array:end))];
                                final_offsets=[final_offsets,cur_offset];
                            end                            
                        elseif curtype==1 %if its an offset, find the preceding onset.                            
                            curtime=sorted_timing(current_bad_sample+1);
                            previous_event_time=sorted_timing(current_bad_sample);                            
                            cur_relevant_segment=filtered_pupil_extrapolated(curtime-1:-1:previous_event_time+1);
                            %first_negative sample after onset:
                            first_neg=find(diff(cur_relevant_segment)<0,1,'first');                            
                            if isempty(first_neg)
                                first_neg=1;
                            end
                            
                            %find the first positive after the negative:
                            first_pos=find(diff(cur_relevant_segment(first_neg:end))>=0,1,'first');                            
                            if isempty(first_pos)
                                first_pos=floor(length(cur_relevant_segment(first_neg:end))/2);
                            end
                            
                            %find the first negative after that pos:
                            offset_sample=find(diff(cur_relevant_segment((first_neg+first_pos+1):end))<0,1,'first');                            
                            if isempty(offset_sample)
                                offset_sample=length(cur_relevant_segment((first_neg+first_pos+1):end));
                            end
                            
                            cur_onset=curtime-1*(first_neg+first_pos+offset_sample);                                                        
                            if isnan(filtered_pupil(cur_onset)); %if the found offset/onset is an extrapolated filtered sample it might be distroted by the filter
                                %thus i will go further forward untill i find the first non nan sample:
                                valid_onset_time=find(~isnan(filtered_pupil(cur_onset-1:-1:1)),1,'first');
                                if isempty(valid_onset_time) %if none was found, remove the onset from the array
                                    sorted_timing(current_bad_sample)=[];
                                    sorted_types(current_bad_sample)=[];
                                else
                                    valid_onset_time=cur_onset-valid_onset_time;
                                    %add the new found offset:
                                    index_in_array=find(valid_onset_time<sorted_timing,1,'first');
                                    sorted_timing=[sorted_timing(1: index_in_array-1),valid_onset_time,(sorted_timing(index_in_array:end))];
                                    sorted_types=[sorted_types(1: index_in_array-1),0,(sorted_types(index_in_array:end))];
                                    final_onsets=[final_onsets,valid_onset_time];
                                end
                            else                                                                
                                %add the new found offset:
                                index_in_array=find(cur_onset<sorted_timing,1,'first');
                                sorted_timing=[sorted_timing(1: index_in_array-1),cur_onset,(sorted_timing(index_in_array:end))];
                                sorted_types=[sorted_types(1: index_in_array-1),0,(sorted_types(index_in_array:end))];
                                final_onsets=[final_onsets,cur_onset];
                            end                            
                        end
                    end
                end
                                                
                %% find an offset for cases in which only an onset was found at the end
                %  of the trial.
                if ~isempty(sorted_types)
                    if sorted_types(end)==0   %the last event is an onset: try and find an offset:
                        curtime=sorted_timing(end);
                        next_event_time=length(filtered_pupil_extrapolated);                        
                        cur_relevant_segment=filtered_pupil_extrapolated(curtime:next_event_time-1);
                        %first_negative sample after onset:
                        first_neg=find(diff(cur_relevant_segment)<0,1,'first');
                        %find the first positive after the negative:
                        first_pos=find(diff(cur_relevant_segment(first_neg:end))>=0,1,'first');
                        %find the first negative after that pos:
                        offset_sample=find(diff(cur_relevant_segment((first_neg+first_pos+1):end))<0,1,'first');
                        cur_offset=curtime+first_neg+first_pos+offset_sample;                        
                        if ~isempty(cur_offset)
                            if isnan(filtered_pupil(cur_offset)); %if the found offset/onset is an extrapolated filtered sample it might be distroted by the filter
                                %thus i will go further forward untill i find the first non nan sample:
                                valid_offset_time=find(~isnan(filtered_pupil(cur_offset:next_event_time-1)),1,'first');
                                if isempty(valid_offset_time) %if none was found, mark all the remaining segment as blinks:
                                    blink_vec(valid_offset_time:end)=1;
                                else
                                    valid_offset_time=cur_offset+valid_offset_time;
                                    %add the new found offset to the end of the array:
                                    sorted_timing=[sorted_timing,valid_offset_time];
                                    sorted_types=[sorted_types,1];
                                    final_offsets=[final_offsets,valid_offset_time];
                                end
                            else                                                                
                                %add the new found offset:
                                sorted_timing=[sorted_timing,cur_offset];
                                sorted_types=[sorted_types,1];
                                final_offsets=[final_offsets,cur_offset];
                            end
                        else
                            blink_vec(curtime:end)=1;
                        end
                        
                    end
                                        
                    %deal with trials that started with an offset:
                    if sorted_types(1)==1; %try to find an onset on the beggining of the trial:
                        first_neg=[];
                        first_pos=[];
                        offset_sample=[];
                        curtime=sorted_timing(1);
                        previous_event_time=1;
                        
                        cur_relevant_segment=filtered_pupil_extrapolated(curtime-1:-1:previous_event_time+1);
                        %first_negative sample after onset:
                        first_neg=find(diff(cur_relevant_segment)<0,1,'first');                        
                        if isempty(first_neg);
                            first_neg=1;
                        end
                        
                        %find the first positive after the negative:
                        first_pos=find(diff(cur_relevant_segment(first_neg:end))>=0,1,'first');                        
                        if isempty(first_pos)
                            first_pos=floor(length(cur_relevant_segment(first_neg:end))/2);
                        end
                                                
                        %find the first negative after that pos:
                        offset_sample=find(diff(cur_relevant_segment((first_neg+first_pos+1):end))<0,1,'first');                        
                        if isempty(offset_sample)
                            offset_sample=length(cur_relevant_segment((first_neg+first_pos+1):end));
                        end
                                                
                        cur_onset=curtime-1*(first_neg+first_pos+offset_sample);                        
                        if ~isempty(cur_onset)
                            if isnan(filtered_pupil(cur_onset)); %if the found offset/onset is an extrapolated filtered sample it might be distroted by the filter
                                %thus i will go further forward untill i find the first non nan sample:
                                valid_onset_time=find(~isnan(filtered_pupil(cur_onset-1:-1:1)),1,'first');
                                if isempty(valid_onset_time) %if none was found, remove the onset from the array
                                    blink_vec(1:curtime)=1;
                                else
                                    valid_onset_time=cur_onset-valid_onset_time;
                                    %add the new found offset:
                                    sorted_timing=[valid_onset_time,sorted_timing];
                                    sorted_types=[0,sorted_types];
                                    final_onsets=[valid_onset_time,final_onsets];
                                end
                            else                                                                
                                %add the new found offset:
                                sorted_timing=[cur_onset,sorted_timing];
                                sorted_types=[0,sorted_types];
                                final_onsets=[cur_onset,final_onsets];
                            end
                        else
                            blink_vec(1:curtime)=1;
                        end
                    end
                                        
                    %             if ~isempty(final_offsets) && sorted_types(1)==1 && final_offsets(1)<1000 %if its an offset, fill the blink vector from the beggining of the epoch
                    %                 blink_vec(1:final_offsets(1))=1;
                    %                 first_offset_flag=1;
                    %             end
                    %
                    %             if ~isempty(final_onsets) && sorted_types(end)==0 && (length(pupildata)-final_onsets(end))<1000 %if the trial ended with an onset fill the rest of the trial with blinks
                    %                 blink_vec(final_onsets(end):length(pupildata))=1;
                    %             end
                    
                    
                    if sorted_types(1)==0                        
                        for i=1:2:length(sorted_timing)-1;
                            blink_vec(sorted_timing(i):sorted_timing(i+1))=1;
                        end
                    else
                        for i=2:2:(length(sorted_timing)-1);
                            blink_vec(sorted_timing(i):sorted_timing(i+1))=1;
                        end
                    end                                                                                                                                           
                end                                
            else
                blink_vec= true(1, length(pupildata));
                problemflag=2; %means that the entire segment was empty
            end            
        end
        
        function lowPassFilter= lowPassFilter(high,signal,rate)
            lowpass =high;
            if nargin < 3
                rate = 1024;
                warndlg(['assuming sampling rate of ' num2str(rate)])
            end
            
            % [nlow,Wnlow]=buttord((0.5*lowpass)/(0.5*rate), lowpass/(0.5*rate) , 0.01, 24);
            [nlow,Wnlow]=buttord( lowpass/(0.5*rate), min(0.999999, 2*lowpass/(0.5*rate)) , 3, 24); % Alon 27.1.09: changed so that high is the cuttoff freq of -3dB
            %disp(['Wnlow = ' num2str(Wnlow)]);
            % [nlow,Wnlow]=buttord((0.5*lowpass)/(0.5*rate), lowpass/(0.5*rate) , 10, 18)
            
            [b,a] = butter(nlow,Wnlow,'low') ;
            lowPassFilter = filtfilt(b,a,signal);
            %figure; plot(signal); hold on;
            %plot(bandPassFilter);
        end
        
        function X = naninterp(X)                                         
            X(isnan(X)) = interp1(find(~isnan(X)), X(~isnan(X)), find(isnan(X)), 'PCHIP');
        end
    end
    
    methods (Access= public, Static)
        function eta = load(full_file_path) 
            loaded_struct = load(full_file_path, '-mat');
            eta = loaded_struct.eta;            
        end
    end        
end

