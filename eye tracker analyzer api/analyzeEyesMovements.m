function reformated_analysis_structs= analyzeEyesMovements(etas_full_paths, segmentation_params, saccades_analysis_params, progress_tracking_callback_func)
    [code_folder, ~, ~] = fileparts(mfilename('fullpath'));
    addpath(fullfile(code_folder, 'code'));
    subjects_nr = numel(etas_full_paths);
    etas= cell(1, subjects_nr);     
    for subject_idx= 1:subjects_nr                                             
        eta= EyeTrackerAnalysisRecord.load(etas_full_paths{subject_idx}); 
        if ~isempty(progress_tracking_callback_func)
            progress_tracking_callback_func(0.2*0.5/subjects_nr);
        end
        was_previous_segmentation_loaded= eta.segmentizeData(progress_tracking_callback_func, 0.2*0.4/subjects_nr, segmentation_params.trial_onset_triggers, segmentation_params.trial_offset_triggers, segmentation_params.trial_rejection_triggers, segmentation_params.baseline, segmentation_params.post_offset_triggers_segment, segmentation_params.trial_duration, saccades_analysis_params.blinks_delta, saccades_analysis_params.blinks_detection_algos_flags);
        if ~was_previous_segmentation_loaded           
            eta.save(etas_full_paths{subject_idx});
        end
        if ~isempty(progress_tracking_callback_func)
            progress_tracking_callback_func(0.2*0.1/subjects_nr);
        end
        etas{subject_idx}= eta;
    end        
         
    saccades_extractor= SaccadesExtractor(etas);
    [eye_data_structs, saccades_analysis_structs]= saccades_extractor.extractSaccadesByEngbert( ...
        saccades_analysis_params.vel_vec_type, ...
        saccades_analysis_params.vel_threshold, ...
        saccades_analysis_params.amp_lim, ...
        saccades_analysis_params.amp_low_lim, ...
        saccades_analysis_params.saccade_dur_min, ...
        saccades_analysis_params.frequency_max, ...
        saccades_analysis_params.filter_bandpass, ...
        etas_full_paths, 0.5, progress_tracking_callback_func);
    was_trigger_ever_found_for_any_subject = false;
    for subject_idx = 1:numel(saccades_analysis_structs)
        if ~isempty(saccades_analysis_structs{subject_idx})
            was_trigger_ever_found_for_any_subject = true;
            break;
        end
    end
    if ~was_trigger_ever_found_for_any_subject
        %subjects_figs = [];
        %statistisized_figs = [];
        %analysis_struct_with_results = [];
        if ~isempty(progress_tracking_callback_func)
            progress_tracking_callback_func(0.5);
        end
        return;
    end

    fixations_analysis_struct = computeFixations(eye_data_structs, 0.2, progress_tracking_callback_func);
    
    saveUpdatedEegStructs(etas, 0.1, progress_tracking_callback_func);
    reformated_analysis_structs= reformatAnalysisStruct();
    %[subjects_figs, statistisized_figs, analysis_struct_with_results]= performMicrosaccadesAnalyses(reformated_analysis_structs, false, [saccades_analysis_params.rate, saccades_analysis_params.amplitudes, saccades_analysis_params.directions, saccades_analysis_params.main_sequence, saccades_analysis_params.gen_single_graphs, saccades_analysis_params.gen_group_graphs], saccades_analysis_params.baseline, saccades_analysis_params.smoothing_window_len, saccades_analysis_params.trial_duration, progress_tracking_callback_func, 0.25);
    %analysis_struct_with_results.saccades_analsysis_parameters = saccades_analysis_params;
    rmpath(fullfile(code_folder, 'code'));
    
    function fixations_analysis_struct = computeFixations(eye_data_structs, progress_contribution, progress_tracking_callback_func)        
        fixations_analysis_struct = cell(1, subjects_nr);
        for subject_i = 1:subjects_nr
            eye_data_struct = eye_data_structs{subject_i};
            if isempty(eye_data_struct)
                if ~isempty(progress_tracking_callback_func)
                    progress_tracking_callback_func(progress_contribution/subjects_nr);
                end
                continue;
            end
            
            conds = fieldnames(eye_data_struct);
            conds_nr = numel(conds);
            fixations_analysis_struct{subject_i}.total.fixations_count = 0;
            fixations_analysis_struct{subject_i}.total.fixations_durations_mean = [];
            for cond_i = 1:conds_nr
                cond = conds{cond_i};
                trials_nr = numel(eye_data_struct.(cond));
                for trial_i = 1:trials_nr
                    if ~any(eye_data_struct.(cond)(trial_i).non_nan_times_logical_vec)
                        % calling getFixationsFromSaccadesDetection with no arguments returns a structure with empty fields
                        fixations_analysis_struct{subject_i}.(cond)(trial_i) = getFixationsFromSaccadesDetection();
                        %progress_screen.addProgress(progress_contribution/(trials_nr*conds_nr*subjects_nr));
                        continue;
                    end
                    
                    d = [(1:numel(eye_data_struct.(cond)(trial_i).non_nan_times_logical_vec))', ...
                        eye_data_struct.(cond)(trial_i).raw_eye_data.right_eye(:,1), ...
                        eye_data_struct.(cond)(trial_i).raw_eye_data.right_eye(:,2), ...
                        eye_data_struct.(cond)(trial_i).raw_eye_data.left_eye(:,1), ...
                        eye_data_struct.(cond)(trial_i).raw_eye_data.left_eye(:,2), ...
                        eye_data_struct.(cond)(trial_i).non_nan_times_logical_vec];
                    
                    fixations_analysis_struct{subject_i}.(cond)(trial_i) = getFixationsFromSaccadesDetection(d, ...
                        saccades_analysis_structs{subject_i}.(cond)(trial_i).onsets', ...
                        saccades_analysis_structs{subject_i}.(cond)(trial_i).offsets', ...
                        saccades_analysis_structs{subject_i}.(cond)(trial_i).amplitudes', ...
                        20, saccades_analysis_params.blinks_delta, false);
                    
                    fixations_nr = numel(fixations_analysis_struct{subject_i}.(cond)(trial_i).onsets);
                    fixations_analysis_struct{subject_i}.total.fixations_count = fixations_analysis_struct{subject_i}.total.fixations_count + fixations_nr;
                    %                         fixations_durs_ratios = min(fixations_struct.durations/TRIAL_DURATION,1);
                    fixations_analysis_struct{subject_i}.total.fixations_durations_mean = ...
                        [fixations_analysis_struct{subject_i}.total.fixations_durations_mean, mean(fixations_analysis_struct{subject_i}.(cond)(trial_i).durations)];
                    %                     f = figure('name', [fig_title, ' - trial #', num2str(trial_i)], 'MenuBar', 'none', 'numbertitle', 'off', 'units', 'pixels');
                    %                     for fixation_i = 1:fixations_nr
                    %                         plot(fixations_coords(fixation_i,1),fixations_coords(fixation_i,2),'.','color',MAX_FIXATION_DUR_COLOR*fixations_durs_ratios(fixation_i),'markersize',20);
                    %                     end
                    if ~isempty(progress_tracking_callback_func) && mod(trial_i, 50) == 0
                        progress_tracking_callback_func(progress_contribution/((trials_nr/50)*conds_nr*subjects_nr));
                    end
                end
                
                if ~isempty(progress_tracking_callback_func)
                    if trials_nr > 0
                        progress_tracking_callback_func(progress_contribution * mod(trials_nr, 50) / (trials_nr*conds_nr*subjects_nr));
                    else
                        progress_tracking_callback_func(progress_contribution/(conds_nr*subjects_nr));
                    end
                end
                %                 savefig(f, fullfile(ANALYSIS_RESULTS_FILE_DESTINATION, ['sub',num2str(subject_i),cond]));
                %                 set(f,'visible','off');
            end
        end
    end

    function saveUpdatedEegStructs(subjects_etas, progress_contribution, progress_tracking_callback_func)        
        for subject_i= 1:subjects_nr
            subject_eta= subjects_etas{subject_i};
            if ~subject_eta.isEegInvolved()
                if ~isempty(progress_tracking_callback_func)
                    progress_tracking_callback_func(progress_contribution/subjects_nr);
                end
                continue;
            end
            segmentized_data_struct= subject_eta.getSegmentizedData(ENGBERT_ALGORITHM_DEFAULTS.filter_bandpass);
            if isempty(segmentized_data_struct)
                if ~isempty(progress_tracking_callback_func)
                    progress_tracking_callback_func(progress_contribution/subjects_nr);
                end
                continue;
            end
            conds_names= fieldnames(segmentized_data_struct);
            EEG= subject_eta.getEyeTrackerDataStructs();
            EEG= EEG{1};
            
            %create the blinks channel
            EEG.data(end+1,:)= boolean(zeros(1,length(EEG.times)));
            EEG.chanlocs(end+1).labels='blinks';
            EEG.chanlocs(end).type='EYE';
            EEG.nbchan=EEG.nbchan+1;
            for cond_i= 1:numel(conds_names)
                curr_cond_segmentized_struct= segmentized_data_struct.(conds_names{cond_i});
                for trial_i= 1:numel(curr_cond_segmentized_struct)
                    curr_trial_onset= curr_cond_segmentized_struct(trial_i).onset_from_session_start;
                    curr_trial_offset= curr_trial_onset+curr_cond_segmentized_struct(trial_i).samples_nr-1;
                    EEG.data(end, curr_trial_onset:curr_trial_offset)= curr_cond_segmentized_struct(trial_i).blinks;
                end
            end
            
            %create the saccades channel
            EEG.data(end+1,:)=boolean(zeros(1,length(EEG.times)));
            EEG.nbchan=EEG.nbchan+1;
            EEG.chanlocs(EEG.nbchan)=EEG.chanlocs(EEG.nbchan-1);
            EEG.chanlocs(EEG.nbchan).labels='sac onset bool';
            analysis_stuct= saccades_analysis_structs{subject_i};
            for cond_i= 1:numel(conds_names)
                curr_cond_name= conds_names{cond_i};
                for trial_i= 1:numel(analysis_stuct.(curr_cond_name))
                    curr_trial_saccades_struct= analysis_stuct.(curr_cond_name)(trial_i);
                    for saccade_i= 1:numel(curr_trial_saccades_struct.onsets)
                        EEG.data(end, curr_trial_saccades_struct.onset_from_session_start(saccade_i))=1;
                        if curr_trial_saccades_struct.user_codes(saccade_i)==Eyeballer.ENUM_ALGORITHM_GENERATED_SACCADE_CODE
                            generator_str= 'algorithm';
                        elseif curr_trial_saccades_struct.user_codes(saccade_i)==Eyeballer.ENUM_USER_GENERATED_SACCADE_CODE
                            generator_str= 'manual';
                        elseif curr_trial_saccades_struct.user_codes(saccade_i)==Eyeballer.ENUM_REJECTED_SACCADE_CODE
                            continue;
                        end
                        EEG.event(end+1).type= ['saccade. generator: ', generator_str];
                        EEG.event(end).latency= curr_trial_saccades_struct.onset_from_session_start(saccade_i);
                        EEG.event(end).duration= curr_trial_saccades_struct.durations(saccade_i);
                        EEG.event(end).endtime= curr_trial_saccades_struct.onset_from_session_start(saccade_i) + curr_trial_saccades_struct.offsets(saccade_i) - curr_trial_saccades_struct.onsets(saccade_i);
                        EEG.event(end).sac_amplitude= curr_trial_saccades_struct.amplitudes(saccade_i);
                    end
                end
            end
            
            [eta_file_path, eta_file_name, ~] = fileparts(etas_full_paths{subject_i});
            pop_saveset(EEG, 'filename', [eta_file_name, '.set'], 'filepath', eta_file_path);
            progress_tracking_callback_func(1/subjects_nr*progress_contribution)
        end
    end

    function reformated_analysis_structs= reformatAnalysisStruct()
        reformated_analysis_structs= cell(1, subjects_nr);
        for subject_i= 1:subjects_nr
            curr_subject_conds_names= fieldnames(saccades_analysis_structs{subject_i});
            if isempty(saccades_analysis_structs{subject_i})
                continue;
            end
            reformated_analysis_structs{subject_i}.saccades = [];            
            reformated_analysis_structs{subject_i}.fixations = [];
            reformated_analysis_structs{subject_i}.raw_data = [];
            for cond_i= 1:numel(curr_subject_conds_names)
                cond = curr_subject_conds_names{cond_i};
                curr_cond_trials_nr= numel(saccades_analysis_structs{subject_i}.(cond));                
                
                reformated_analysis_structs{subject_i}.saccades.(cond).number_of_saccades= zeros(1, curr_cond_trials_nr);
                reformated_analysis_structs{subject_i}.saccades.(cond).durations= cell(1, curr_cond_trials_nr);
                reformated_analysis_structs{subject_i}.saccades.(cond).amplitudes= cell(1, curr_cond_trials_nr);
                reformated_analysis_structs{subject_i}.saccades.(cond).directions= cell(1, curr_cond_trials_nr);
                reformated_analysis_structs{subject_i}.saccades.(cond).onsets= cell(1, curr_cond_trials_nr);
                reformated_analysis_structs{subject_i}.saccades.(cond).velocities= cell(1, curr_cond_trials_nr);                
                
                max_trial_dur = 0;
                for trial_i= 1:curr_cond_trials_nr
                    curr_trial_dur = numel(eye_data_structs{subject_i}.(cond)(trial_i).non_nan_times_logical_vec);
                    if max_trial_dur < curr_trial_dur
                        max_trial_dur = curr_trial_dur;
                    end
                end
                reformated_analysis_structs{subject_i}.saccades.(cond).logical_onsets_mat= zeros(curr_cond_trials_nr, max_trial_dur);
                reformated_analysis_structs{subject_i}.raw_data.(cond).vergence.x = NaN(curr_cond_trials_nr, max_trial_dur);
                reformated_analysis_structs{subject_i}.raw_data.(cond).vergence.y = NaN(curr_cond_trials_nr, max_trial_dur);
                reformated_analysis_structs{subject_i}.raw_data.(cond).non_nan_times= NaN(curr_cond_trials_nr, max_trial_dur);
                reformated_analysis_structs{subject_i}.raw_data.(cond).right_eye.x= NaN(curr_cond_trials_nr, max_trial_dur);
                reformated_analysis_structs{subject_i}.raw_data.(cond).right_eye.y= NaN(curr_cond_trials_nr, max_trial_dur);
                reformated_analysis_structs{subject_i}.raw_data.(cond).left_eye.x= NaN(curr_cond_trials_nr, max_trial_dur);
                reformated_analysis_structs{subject_i}.raw_data.(cond).left_eye.y= NaN(curr_cond_trials_nr, max_trial_dur);                
                
                for trial_i= 1:curr_cond_trials_nr
                    curr_trial_saccades_struct= saccades_analysis_structs{subject_i}.(cond)(trial_i);
                    curr_trial_fixations_struct= fixations_analysis_struct{subject_i}.(cond)(trial_i);
                    curr_trial_eye_data_struct = eye_data_structs{subject_i}.(cond)(trial_i);                    
                    if ~isempty(curr_trial_eye_data_struct) && ~isempty(curr_trial_eye_data_struct.non_nan_times_logical_vec)
                        curr_trial_dur = numel(curr_trial_eye_data_struct.non_nan_times_logical_vec);
                        reformated_analysis_structs{subject_i}.raw_data.(cond).vergence.x(trial_i, 1:curr_trial_dur)  = ...
                            curr_trial_eye_data_struct.vergence(:,1)';
                        reformated_analysis_structs{subject_i}.raw_data.(cond).vergence.y(trial_i, 1:curr_trial_dur) = ...
                            curr_trial_eye_data_struct.vergence(:,2)';
                        reformated_analysis_structs{subject_i}.raw_data.(cond).non_nan_times(trial_i, 1:curr_trial_dur)= ...
                            curr_trial_eye_data_struct.non_nan_times_logical_vec';
                        reformated_analysis_structs{subject_i}.raw_data.(cond).right_eye.x(trial_i, 1:curr_trial_dur) = curr_trial_eye_data_struct.raw_eye_data.right_eye(:,1)';
                        reformated_analysis_structs{subject_i}.raw_data.(cond).right_eye.y(trial_i, 1:curr_trial_dur) = curr_trial_eye_data_struct.raw_eye_data.right_eye(:,2)';
                        reformated_analysis_structs{subject_i}.raw_data.(cond).left_eye.x(trial_i, 1:curr_trial_dur) = curr_trial_eye_data_struct.raw_eye_data.left_eye(:,1)';
                        reformated_analysis_structs{subject_i}.raw_data.(cond).left_eye.y(trial_i, 1:curr_trial_dur) = curr_trial_eye_data_struct.raw_eye_data.left_eye(:,2)';                            
                    end

                    if ~isempty(curr_trial_saccades_struct.onsets) && any(~isnan(curr_trial_saccades_struct.onsets))
                        reformated_analysis_structs{subject_i}.saccades.(cond).logical_onsets_mat(trial_i, curr_trial_saccades_struct.onsets)= 1;
                        reformated_analysis_structs{subject_i}.saccades.(cond).logical_onsets_mat(trial_i, curr_trial_dur+1:max_trial_dur) = NaN;
                        reformated_analysis_structs{subject_i}.saccades.(cond).number_of_saccades(trial_i)= ...
                            numel(curr_trial_saccades_struct.onsets);
                        reformated_analysis_structs{subject_i}.saccades.(cond).durations{trial_i}= ...
                            curr_trial_saccades_struct.durations';
                        reformated_analysis_structs{subject_i}.saccades.(cond).amplitudes{trial_i}= ...
                            curr_trial_saccades_struct.amplitudes';
                        reformated_analysis_structs{subject_i}.saccades.(cond).directions{trial_i}= ...
                            curr_trial_saccades_struct.directions';
                        reformated_analysis_structs{subject_i}.saccades.(cond).onsets{trial_i}= ...
                            curr_trial_saccades_struct.onsets';
                        reformated_analysis_structs{subject_i}.saccades.(cond).velocities{trial_i}= ...
                            curr_trial_saccades_struct.velocities';                        
                    end
                    
                    if ~isempty(curr_trial_fixations_struct.onsets) && any(~isnan(curr_trial_fixations_struct.onsets))
                        reformated_analysis_structs{subject_i}.fixations.(cond).onsets{trial_i} = curr_trial_fixations_struct.onsets;
                        reformated_analysis_structs{subject_i}.fixations.(cond).coordinates_left{trial_i} = [curr_trial_fixations_struct.Hpos(:,1), curr_trial_fixations_struct.Vpos(:,1)];
                        reformated_analysis_structs{subject_i}.fixations.(cond).coordinates_right{trial_i} = [curr_trial_fixations_struct.Hpos(:,2), curr_trial_fixations_struct.Vpos(:,2)];
                        reformated_analysis_structs{subject_i}.fixations.(cond).durations{trial_i} = curr_trial_fixations_struct.durations;
                    end
                end
            end
        end
    end
end