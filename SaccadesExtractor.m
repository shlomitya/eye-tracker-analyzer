classdef SaccadesExtractor < handle
    % class for storing the parameterizations and variables relating to
    % saccades extraction, and to perform the saccades extraction
    properties (Access= public, Constant)        
        EYEBALLER_MAIN_GUI_BACKGROUND_COLOR= [0.8, 0.8, 0.8];        
        ENUM_VEL_CALC_TYPE_1= 1;
        ENUM_VEL_CALC_TYPE_RUNNING_MEAN= 2;
        ENUM_VEL_CALC_TYPE_3= 3;                
    end
    
    properties (Access= private)        
        subjects_etas;        
        subjects_nr;        
        dpps;        
        sampling_rates;        
        engbert_algorithm_params;
        % engbert_algorithm_interm_vars: caches intermediate variables computed by engbert's algorithm
        % that are reused multiple times
        engbert_algorithm_interm_vars;       
        eyeballer_main_gui_pos;
    end
    
    methods (Access= public)          
        function obj= SaccadesExtractor(subjects_etas)
            % SaccadesExtractor ctr
            % input:
            %   subjects_etas -> cell array of EyeTrackerAnalysisRecord objects. 
            
            if ~iscell(subjects_etas)
                subjects_etas= {subjects_etas};
            end
            obj.subjects_etas= subjects_etas; 
            obj.subjects_nr= numel(subjects_etas);  
            obj.dpps = NaN(1,obj.subjects_nr);
            for subject_i = 1:obj.subjects_nr
                obj.dpps(subject_i)= subjects_etas{subject_i}.getDpp();
                obj.sampling_rates(subject_i)= subjects_etas{subject_i}.getSamplingRate();
            end                          
                 
            screen_size= get(0,'monitorpositions');
            if any(screen_size(1)<0)
                screen_size= get(0,'ScreenSize');
            end
            
            screen_size= screen_size(1,:);
            obj.eyeballer_main_gui_pos= round([0.2*screen_size(3), -0.2*screen_size(4), 0.6*screen_size(3), 0.8*screen_size(4)]);
        end
        
        function [eye_data_struct, saccades_struct, eyeballing_stats]= extractSaccadesByEngbert(obj, detection_requested, vel_calc_type, vel_threshold, amp_lim, amp_low_lim, saccade_dur_min, frequency_max, filter_bandpass, perform_eyeballing, eyeballer_display_range_multiplier, eyeballer_timeline_left_offset, etas_full_paths, progress_contribution, progress_screen, logger)                           
            % perform the saccades extraction
            % input:
            %   * detection_requested -> monocular or binocular detection.
            %   values according to the enumeration defined in EyeTrackerAnalysisRecord.
            %   * vel_calc_type -> method to calculate the eyes velocity.
            %   values according to the VEL_CALC enumeration defined above.
            %   * vel_threshold -> threshold velocity for the ellipse
            %   equation in engbert's algorithm test criterion.
            %   * amp_lim -> maximum amplitude for a saccade above which
            %   to discard the saccade.
            %   * amp_low_lim -> minimum amplitude for a saccade below which
            %   to discard the saccade.
            %   * saccade_dur_min -> minimum duration for a saccade below which
            %   to discard the saccade.
            %   * frequency_max -> time interval after a detected saccade 
            %   within which to discard later found saccades.
            %   * filter_bandpass -> filter lowpass frequency to apply on
            %   the eyes tracking data
            %   * perform_eyeballing -> whether or not to perform a manual
            %   analysis inspection
            %   * eyeballer_display_range_multiplier [perform_eyeballing == true] -> 
            %   define this as a factor in computing the eyes'
            %   data plots Y axes ranges.
            %   * eyeballer_timeline_left_offset [perform_eyeballing == true] -> 
            %   offset to apply to the time axes in the eyeballer's eyes' data plots.
            %   * etas_full_paths [perform_eyeballing == true] -> full file paths to
            %   save the updated EyeTrackerAnalysisRecord files.
            %   * progress_contribution -> factor to scale progress with
            %   * progress_screen -> DualBarProgressScreen to add progress to
            %   * logger -> Logger object with which to log messages.
            %
            % output:
            %   * eye_data_struct 
            %   * saccades_struct 
            %   * eyeballing_stats
                                    
            if perform_eyeballing
                % eye positions data to pass to the eyeballer. this is the
                % data the eyeballer plots.
                raw_eye_data_for_eyeballer= cell(1, obj.subjects_nr);
                % parameters to be passed by the eyeballer to the function
                % performing a saccade search when an eye positions plot is
                % clicked on in the eyeballer
                manual_saccades_search_func_params_for_eyeballer= cell(1, obj.subjects_nr);
            end
            
            % segmentized data per subject 
            subjects_data_structs= cell(1,obj.subjects_nr);
            % output variable
            saccades_struct= cell(1, obj.subjects_nr);
            % output variable
            eye_data_struct = cell(1, obj.subjects_nr);
            % output variable
            eyeballing_stats= [];
            % initializing the parameters for the saccades extraction.
            % if the user requests a re-extraction in the eyeballer, these
            % variables will be assigned with the re-extraction parameters
            curr_requested_vel_calc_type= vel_calc_type;
            curr_requested_vel_threshold= vel_threshold;
            curr_requested_amp_lim= amp_lim;
            curr_requested_amp_low_lim = amp_low_lim;
            curr_requested_saccade_dur_min= saccade_dur_min;
            curr_requested_frequency_max= frequency_max; 
            curr_requested_low_pass_filter = filter_bandpass;  
            
            was_new_extraction_requested_by_eyeballer= false;
            is_extraction_go= true;
            % the while condition runs every time the user requests a saccades 
            % re-extraction in the eyeballer                       
            while is_extraction_go    
                % segmentizing the data to conditions for all subjects.
                progress_screen.updateProgress(0);
                for subject_i= 1:obj.subjects_nr                    
                    [subjects_data_structs{subject_i}, detection_performed]= obj.subjects_etas{subject_i}.getSegmentizedData(detection_requested, progress_screen, 0.8*progress_contribution/obj.subjects_nr, curr_requested_low_pass_filter);                                    
                    previous_saccades_analysis= obj.subjects_etas{subject_i}.loadSaccadesAnalysis();                                       
                    if ~isempty(previous_saccades_analysis)
                        % if a previous analysis was saved via the eyeballer
                        % for the segmentization defined by the current run
                        % parameters, save the saccades data into the output
                        % variables, and later skip the saccades extraction
                        % code.
                        if perform_eyeballing
                            raw_eye_data_for_eyeballer{subject_i}= previous_saccades_analysis.raw_eye_data;
                            manual_saccades_search_func_params_for_eyeballer{subject_i}= previous_saccades_analysis.manual_saccades_search_func_params;                        
                        end

                        saccades_struct{subject_i}= previous_saccades_analysis.saccades_struct;   
                        eye_data_struct{subject_i}= previous_saccades_analysis.eye_data_struct;  
                    end
                end
                
                for subject_i= 1:obj.subjects_nr                    
                    if ~was_new_extraction_requested_by_eyeballer && ~isempty(saccades_struct{subject_i})    
                        % skip the saccades extraction for the current
                        % subject if re-extraction was not requested in the
                        % gui and if a previous extraction was found.
                        progress_screen.addProgress(0.2*progress_contribution/obj.subjects_nr);
                        continue;
                    end
                    
                    curr_subject_data_struct= subjects_data_structs{subject_i};
                    if isempty(curr_subject_data_struct)
                        % if the segmentization produced no data segments.
                        progress_screen.addProgress(0.2*progress_contribution/obj.subjects_nr);
                        continue;
                    end
                                        
                    conds_names= fieldnames(curr_subject_data_struct);                    
                    for cond_i= 1:numel(conds_names)                  
                        curr_cond_name= conds_names{cond_i};
                        curr_cond_struct= curr_subject_data_struct.(curr_cond_name); 
                        eye_data_struct{subject_i}.(curr_cond_name) = [];
                        saccades_struct{subject_i}.(curr_cond_name) = [];                       
                        if perform_eyeballing
                            % initialize data expected by the eyeballer
                            raw_eye_data_for_eyeballer{subject_i}.(curr_cond_name) = [];
                            manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name) = [];
                        end
                        for trial_i= 1:numel(curr_cond_struct)                                                               
                            blink= squeeze(curr_cond_struct(trial_i).blinks);                            
                            if isempty(blink) || all(blink)
                                % no data was recorded during the entire trial's length. 
                                % assign empty vectors to all output variables.
                                if perform_eyeballing
                                    raw_eye_data_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).left_x= [];
                                    raw_eye_data_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).left_y= [];
                                    raw_eye_data_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).right_x= [];
                                    raw_eye_data_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).right_y= [];
                                    raw_eye_data_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).non_nan_times_logical_vec= [];
                                    manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).left_eye.eye_vels= [];
                                    manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).right_eye.eye_vels= [];
                                    manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).left_eye.baseline_corrected_eye_data= [];
                                    manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).right_eye.baseline_corrected_eye_data= [];
                                    manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).non_nan_times_logical_vec= [];                                    
                                end                                
                                
                                fillSaccadesStructWithVal([]);
                                eye_data_struct{subject_i}.(curr_cond_name)(trial_i).non_nan_times_logical_vec = [];
                                eye_data_struct{subject_i}.(curr_cond_name)(trial_i).vergence = [];
                                continue;
                            end
                            
                            raw_eye_data_mat= [1:curr_cond_struct(trial_i).samples_nr; ...           
                                               curr_cond_struct(trial_i).gazeRight.x; ...
                                               curr_cond_struct(trial_i).gazeRight.y; ...
                                               curr_cond_struct(trial_i).gazeLeft.x; ...
                                               curr_cond_struct(trial_i).gazeLeft.y]';
                                                                                    
                            %non_nan_times_logical_vec holds 1s for non-nan data times and 0 for nan data times
                            non_nan_times_logical_vec= ~isnan(raw_eye_data_mat(:,2)) & ~isnan(raw_eye_data_mat(:,3)) & ~blink';    
                            eye_data_struct{subject_i}.(curr_cond_name)(trial_i).non_nan_times_logical_vec = non_nan_times_logical_vec;
                            
                            %now raw_eye_data_mat should contain only non-null data points
                            raw_eye_data_mat= raw_eye_data_mat(non_nan_times_logical_vec,:);                            
                                                        
                            % baseline-correct the eyes data
                            % xr - right eye positions. xl - left eye positions
                            % xr(:,1), xl(:,1) - eye positions x coordinates
                            % xr(:,2), xl(:,2) - eye positions y coordinates
                            xr = obj.dpps(subject_i)*raw_eye_data_mat(:,2:3);
                            xr(:,1) = xr(:,1) - mean(xr(:,1));
                            xr(:,2) = xr(:,2) - mean(xr(:,2));
                            obj.engbert_algorithm_interm_vars{subject_i}.(curr_cond_name)(trial_i).right_eye.baseline_corrected_eye_data= xr;
                            xl = obj.dpps(subject_i)*raw_eye_data_mat(:,4:5);
                            xl(:,1) = xl(:,1) - mean(xl(:,1));
                            xl(:,2) = xl(:,2) - mean(xl(:,2));
                            obj.engbert_algorithm_interm_vars{subject_i}.(curr_cond_name)(trial_i).left_eye.baseline_corrected_eye_data= xl;
                            eye_data_struct{subject_i}.(curr_cond_name)(trial_i).vergence =  NaN(curr_cond_struct(trial_i).samples_nr,2);                           
                            eye_data_struct{subject_i}.(curr_cond_name)(trial_i).vergence(non_nan_times_logical_vec, :) = [xr(:,1) - xl(:,1), xr(:,2) - xl(:,2)];
                            eye_data_struct{subject_i}.(curr_cond_name)(trial_i).raw_eye_data.right_eye = [curr_cond_struct(trial_i).gazeRight.x; curr_cond_struct(trial_i).gazeRight.y]';                                
                            eye_data_struct{subject_i}.(curr_cond_name)(trial_i).raw_eye_data.left_eye = [curr_cond_struct(trial_i).gazeLeft.x; curr_cond_struct(trial_i).gazeLeft.y]';                            
                            
                            
                            % Compute 2D velocity vectors
                            obj.engbert_algorithm_interm_vars{subject_i}.(curr_cond_name)(trial_i).left_eye.eye_vels = ...
                                SaccadesExtractor.vecvel(obj.engbert_algorithm_interm_vars{subject_i}.(curr_cond_name)(trial_i).left_eye.baseline_corrected_eye_data, ...
                                                         curr_requested_vel_calc_type, ...
                                                         obj.sampling_rates(subject_i));
                            obj.engbert_algorithm_interm_vars{subject_i}.(curr_cond_name)(trial_i).right_eye.eye_vels = ...
                                SaccadesExtractor.vecvel(obj.engbert_algorithm_interm_vars{subject_i}.(curr_cond_name)(trial_i).right_eye.baseline_corrected_eye_data, ...
                                                         curr_requested_vel_calc_type, ...
                                                         obj.sampling_rates(subject_i));
                            obj.engbert_algorithm_params.vel_calc_type= curr_requested_vel_calc_type;
                            
                            if perform_eyeballing            
                                % cache variables to be used by the saccade search function 
                                % that is run when the user requests to find a saccade in the 
                                % insepector on a specific time.
                                manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).left_eye.eye_vels= ...
                                    NaN(numel(raw_eye_data_mat(:,1)), 2);
                                manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).left_eye.eye_vels(non_nan_times_logical_vec,:)= ...
                                    obj.engbert_algorithm_interm_vars{subject_i}.(curr_cond_name)(trial_i).left_eye.eye_vels;                                
                                
                                manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).right_eye.eye_vels= ...
                                    NaN(numel(raw_eye_data_mat(:,1)), 2);
                                manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).right_eye.eye_vels(non_nan_times_logical_vec,:)= ...
                                    obj.engbert_algorithm_interm_vars{subject_i}.(curr_cond_name)(trial_i).right_eye.eye_vels;                                                                
                                manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).left_eye.baseline_corrected_eye_data= ...
                                    NaN(numel(raw_eye_data_mat(:,1)), 2);
                                manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).left_eye.baseline_corrected_eye_data(non_nan_times_logical_vec,:)= ...
                                    obj.engbert_algorithm_interm_vars{subject_i}.(curr_cond_name)(trial_i).left_eye.baseline_corrected_eye_data;                                
                                manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).right_eye.baseline_corrected_eye_data= ...
                                    NaN(numel(raw_eye_data_mat(:,1)), 2);
                                manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).right_eye.baseline_corrected_eye_data(non_nan_times_logical_vec,:)= ...
                                    obj.engbert_algorithm_interm_vars{subject_i}.(curr_cond_name)(trial_i).right_eye.baseline_corrected_eye_data;                                
                                
                                raw_eye_data_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).left_x= ...
                                    manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).left_eye.baseline_corrected_eye_data(:,1)';
                                raw_eye_data_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).left_y= ...
                                    manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).left_eye.baseline_corrected_eye_data(:,2)';
                                raw_eye_data_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).right_x= ...
                                    manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).right_eye.baseline_corrected_eye_data(:,1)';
                                raw_eye_data_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).right_y= ...
                                    manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).right_eye.baseline_corrected_eye_data(:,2)';
                                
                                manual_saccades_search_func_params_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).non_nan_times_logical_vec= non_nan_times_logical_vec;
                                raw_eye_data_for_eyeballer{subject_i}.(curr_cond_name)(trial_i).non_nan_times_logical_vec= non_nan_times_logical_vec';
                            end
                            
                            % Detection of saccades    
                            try
                                [sacl, ~] = SaccadesExtractor.engbertAlgorithm(obj.engbert_algorithm_interm_vars{subject_i}.(curr_cond_name)(trial_i).left_eye.eye_vels, ...
                                                                               curr_requested_vel_threshold, ...
                                                                               max(ceil(curr_requested_saccade_dur_min*obj.sampling_rates(subject_i)/1000),2));
                                [sacr, ~] = SaccadesExtractor.engbertAlgorithm(obj.engbert_algorithm_interm_vars{subject_i}.(curr_cond_name)(trial_i).right_eye.eye_vels, ...
                                                                               curr_requested_vel_threshold, ...
                                                                               max(ceil(curr_requested_saccade_dur_min*obj.sampling_rates(subject_i)/1000), 2));
                            catch exception                                
                                exception_identifier= strsplit(exception.identifier,':');
                                exception_identifier= exception_identifier{2};
                                if strcmp(exception_identifier, 'msdxZero') || strcmp(exception_identifier, 'msdyZero')
                                    logger.logi(['On condition ', curr_cond_name, ' trial #', num2str(trial_i), ': ', exception.message]);
                                    fillSaccadesStructWithVal([]);                                    
                                else
                                    logger.loge(['On condition ', curr_cond_name, ' trial #', num2str(trial_i), ': ', exception.message]);
                                    progress_screen.displayMessage('<<ERROR: see log file>>');                                    
                                end
                                
                                continue;
                            end
                            
                            if isempty(sacl) || isempty(sacr)
                                fillSaccadesStructWithVal([]);
                                continue;
                            end
                            
                            % Calculate 1d saccades displacements
                            ampsl= SaccadesExtractor.calcSaccadesAmplitudes(obj.engbert_algorithm_interm_vars{subject_i}.(curr_cond_name)(trial_i).left_eye.baseline_corrected_eye_data, ...
                                                                            sacl(:,1), sacl(:,2));
                            ampsr= SaccadesExtractor.calcSaccadesAmplitudes(obj.engbert_algorithm_interm_vars{subject_i}.(curr_cond_name)(trial_i).right_eye.baseline_corrected_eye_data, ...
                                                                            sacr(:,1), sacr(:,2));  
                                                                        
                            % Testing for binocular saccades via temporal overlap
                            [sacl, sacr, ~, ~, kept_left_is, kept_right_is] = SaccadesExtractor.binsacc(sacl, sacr, ampsl, ampsr);                            
                            if isempty(sacl) || isempty(sacr)
                                fillSaccadesStructWithVal([]);
                                continue;
                            end                     
                            % keeping only saccades displacements corresponding to the binsacc 
                            % kept saccades 
                            ampsl= ampsl(kept_left_is,:);                            
                            ampsr= ampsr(kept_right_is,:); 
                            % calculate saccades amplitudes averaged over both eyes
                            amplitudes = (sqrt(ampsr(:,1).^2 + ampsr(:,2).^2) + sqrt(ampsl(:,1).^2 + ampsl(:,2).^2)) / 2;
                            
                            non_nan_times= find(non_nan_times_logical_vec);                                                        
                            % find saccades onsets as the earliest non-nan samples between 
                            % left and right found saccades
                            curr_trial_onsets = non_nan_times(min([sacr(:,1)'; sacl(:,1)'])');                            
                            % find saccades offsets as the latest non-nan samples between 
                            % left and right found saccades
                            curr_trial_offsets = non_nan_times(max([sacr(:,2)'; sacl(:,2)'])');
                            
                            % keep saccades that occur on time inervals during which 
                            % all samples are non-nan
                            saccades_on_non_nan_times_idxs = [];
                            for saccade_idx = 1:numel(curr_trial_onsets)
                                if all(non_nan_times_logical_vec(curr_trial_onsets(saccade_idx):curr_trial_offsets(saccade_idx)))
                                    saccades_on_non_nan_times_idxs = [saccades_on_non_nan_times_idxs, saccade_idx];
                                end
                            end
                            sacl= sacl(saccades_on_non_nan_times_idxs,:);
                            sacr= sacr(saccades_on_non_nan_times_idxs,:);
                            ampsl= ampsl(saccades_on_non_nan_times_idxs,:);
                            ampsr= ampsr(saccades_on_non_nan_times_idxs,:);
                            amplitudes= amplitudes(saccades_on_non_nan_times_idxs,:);
                            curr_trial_onsets = curr_trial_onsets(saccades_on_non_nan_times_idxs);
                            curr_trial_offsets = curr_trial_offsets(saccades_on_non_nan_times_idxs);
                            
                            %allow only one saccade within a time window of curr_requested_frequency_max
                            %keep only the largest saccades within this time window                   
                            if numel(curr_trial_onsets) > 1
                                spoints=curr_requested_frequency_max*(obj.sampling_rates(subject_i)/1000);                            
                                donsets= curr_trial_onsets(2:end) - curr_trial_offsets(1:end-1);
                                maxAmp=amplitudes(1);
                                inds=[];
                                iMaxInd=1;
                                i=2;
                                while i<=length(curr_trial_onsets)
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
                                if ~any(inds)
                                    fillSaccadesStructWithVal([]);
                                    continue;
                                end                            
                                sacl= sacl(inds,:);
                                sacr= sacr(inds,:);
                                ampsl= ampsl(inds,:);
                                ampsr= ampsr(inds,:);
                                amplitudes= amplitudes(inds,:);
                                curr_trial_onsets= curr_trial_onsets(inds);
                                curr_trial_offsets = curr_trial_offsets(inds);
                            end
                                     
                            % keep saccades whose amplitude is within the range specified by the user
                            amplitudes_inside_limits_is= curr_requested_amp_low_lim < amplitudes & amplitudes < curr_requested_amp_lim;                            
                            if ~any(amplitudes_inside_limits_is)
                                fillSaccadesStructWithVal([]);
                                continue;
                            end                            
                            sacl= sacl(amplitudes_inside_limits_is,:);
                            sacr= sacr(amplitudes_inside_limits_is,:);
                            ampsl= ampsl(amplitudes_inside_limits_is,:);
                            ampsr= ampsr(amplitudes_inside_limits_is,:);
                            amplitudes= amplitudes(amplitudes_inside_limits_is,:);                                        
                            curr_trial_onsets= curr_trial_onsets(amplitudes_inside_limits_is);                                                        
                            curr_trial_offsets = curr_trial_offsets(amplitudes_inside_limits_is);
                            
                            % calculate durations for the kept saccades
                            DR = (sacr(:,2)-sacr(:,1)+1)*1000/obj.sampling_rates(subject_i);
                            DL = (sacl(:,2)-sacl(:,1)+1)*1000/obj.sampling_rates(subject_i);
                            curr_trial_saccades_durs= (DR+DL)/2;
                            
                            % calculate delays between eyes for the kept saccades
                            curr_trial_delays_between_eyes= (sacr(:,1) - sacl(:,1))*1000/obj.sampling_rates(subject_i);
                            
                            % calculate directions for the kept saccades
                            curr_trial_directions = atan2((ampsr(:,2)+ampsl(:,2))/2,(ampsr(:,1)+ampsl(:,1))/2);
                               
                            % calculate mean speed and peak speed for the kept saccades
                            curr_trial_saccades_nr= numel(curr_trial_onsets);
                            curr_trial_peak_vels= zeros(curr_trial_saccades_nr, 1);
                            vels = zeros(curr_trial_saccades_nr, 1);
                            left_eye_vels= obj.engbert_algorithm_interm_vars{subject_i}.(curr_cond_name)(trial_i).left_eye.eye_vels;
                            right_eye_vels= obj.engbert_algorithm_interm_vars{subject_i}.(curr_cond_name)(trial_i).right_eye.eye_vels;
                            for saccade_i= 1:curr_trial_saccades_nr
                                left_eye_vels_on_saccade= left_eye_vels(sacl(saccade_i,1):sacl(saccade_i,2), :);
                                left_eye_vels_on_saccade_szs = sqrt( left_eye_vels_on_saccade(:,1).^2 + left_eye_vels_on_saccade(:,2).^2 );
                                right_eye_vels_on_saccade= right_eye_vels(sacr(saccade_i,1):sacr(saccade_i,2), :);
                                right_eye_vels_on_saccade_szs = sqrt( right_eye_vels_on_saccade(:,1).^2 + right_eye_vels_on_saccade(:,2).^2 );
                                
                                vels(saccade_i) = (mean(left_eye_vels_on_saccade_szs) + mean(right_eye_vels_on_saccade_szs))/2; 
                                
                                left_eye_peak_vel= max(left_eye_vels_on_saccade_szs);                                                                                                
                                right_eye_peak_vel= max(right_eye_vels_on_saccade_szs);                                
                                curr_trial_peak_vels(saccade_i)= (left_eye_peak_vel + right_eye_peak_vel)/2;                                      
                            end                            
                            
                            % save all calculated variables in the output struct
                            saccades_struct{subject_i}.(curr_cond_name)(trial_i).onsets= curr_trial_onsets;
                            saccades_struct{subject_i}.(curr_cond_name)(trial_i).offsets= curr_trial_offsets;
                            saccades_struct{subject_i}.(curr_cond_name)(trial_i).durations = curr_trial_saccades_durs;
                            saccades_struct{subject_i}.(curr_cond_name)(trial_i).delays_between_eyes= curr_trial_delays_between_eyes;
                            saccades_struct{subject_i}.(curr_cond_name)(trial_i).amplitudes= amplitudes;                           
                            saccades_struct{subject_i}.(curr_cond_name)(trial_i).directions= -curr_trial_directions;
                            saccades_struct{subject_i}.(curr_cond_name)(trial_i).velocities= vels;
                            saccades_struct{subject_i}.(curr_cond_name)(trial_i).peak_vels= curr_trial_peak_vels;                                                        
                        end                                                                          
                    end    
                    
                    progress_screen.addProgress(0.2*progress_contribution/obj.subjects_nr);
                end                                                                                                
                     
                % check if any of the triggers requested was found for any of the subjects
                was_any_trigger_ever_found = false;
                for subject_i = 1:obj.subjects_nr
                    if ~isempty(saccades_struct{subject_i})
                        was_any_trigger_ever_found = true;
                        break;
                    end
                end

                % if none of the triggers requested was found for any of the subjects, skip the data inspection
                if perform_eyeballing && was_any_trigger_ever_found    
                    % aggregate saccades extraction parameters to a structure for the Eyeballer ctor
                    manual_saccade_search_params.manual_saccade_search_func = @SaccadesExtractor.findSaccadeForcefullyOnDefinedTimesByEngbert;
                    manual_saccade_search_params.manual_saccade_search_func_input = manual_saccades_search_func_params_for_eyeballer;
                    manual_saccade_search_params.saccades_detecetion_algorithm_params.amp_lim = curr_requested_amp_lim;
                    manual_saccade_search_params.saccades_detecetion_algorithm_params.amp_low_lim = curr_requested_amp_low_lim;
                    manual_saccade_search_params.saccades_detecetion_algorithm_params.vel_threshold = curr_requested_vel_threshold;
                    manual_saccade_search_params.saccades_detecetion_algorithm_params.saccade_dur_min = curr_requested_saccade_dur_min;
                    manual_saccade_search_params.saccades_detecetion_algorithm_params.frequency_max = curr_requested_frequency_max;
                    manual_saccade_search_params.saccades_detecetion_algorithm_params.low_pass_filter = curr_requested_low_pass_filter;
                    % create an Eyeballer
                    eyeballer= Eyeballer(@eyeballer_save_func, raw_eye_data_for_eyeballer, detection_performed, eyeballer_timeline_left_offset, obj.sampling_rates, ...
                                         manual_saccade_search_params, saccades_struct, eyeballer_display_range_multiplier, ...
                                         obj.eyeballer_main_gui_pos, obj.EYEBALLER_MAIN_GUI_BACKGROUND_COLOR);
                    % run the data inspection
                    [was_new_extraction_requested_by_eyeballer, new_extraction_params]= eyeballer.run();                    
                    if ~was_new_extraction_requested_by_eyeballer
                        is_extraction_go= false;                        
                        [saccades_struct, eyeballing_stats]= eyeballer.getSaccadesStruct();   
                    else
                        curr_requested_amp_lim= new_extraction_params.amp_lim;
                        curr_requested_amp_low_lim= new_extraction_params.amp_low_lim;
                        curr_requested_vel_threshold= new_extraction_params.vel_threshold;
                        curr_requested_saccade_dur_min = new_extraction_params.min_dur_for_saccade;
                        curr_requested_frequency_max = new_extraction_params.min_dur_between_saccades;
                        curr_requested_low_pass_filter = new_extraction_params.low_pass_filter;                                                
                        saccades_struct= cell(1, obj.subjects_nr);
                        eyeballer_display_range_multiplier = new_extraction_params.eyeballer_display_range_multiplier;
                    end
                else
                    is_extraction_go= false;
                end                                
            end 
            
            %add a field for the saccades' onsets relative to the start of the session.
            for subject_i= 1:obj.subjects_nr   
                if isempty(saccades_struct{subject_i})
                    continue;
                end
                conds_names= fieldnames(saccades_struct{subject_i});
                for cond_i= 1:numel(conds_names)
                    curr_cond_name= conds_names{cond_i};
                    for trial_i= 1:numel(saccades_struct{subject_i}.(curr_cond_name))
                        saccades_struct{subject_i}.(curr_cond_name)(trial_i).onset_from_session_start= ...
                            saccades_struct{subject_i}.(curr_cond_name)(trial_i).onsets + ...
                            subjects_data_structs{subject_i}.(curr_cond_name)(trial_i).onset_from_session_start;
                    end
                end
            end
                        
            function fillSaccadesStructWithVal(val)
                % fills a saccades data structure with a specific value for the currently iterated
                % subject-condition-trial combination.
                % input:
                %   * val -> the value to fill the saccades data structure with
                saccades_struct{subject_i}.(curr_cond_name)(trial_i).onsets= val;
                saccades_struct{subject_i}.(curr_cond_name)(trial_i).offsets= val;
                saccades_struct{subject_i}.(curr_cond_name)(trial_i).durations = val;
                saccades_struct{subject_i}.(curr_cond_name)(trial_i).delays_between_eyes= val;
                saccades_struct{subject_i}.(curr_cond_name)(trial_i).amplitudes= val;
                saccades_struct{subject_i}.(curr_cond_name)(trial_i).directions= val;
                saccades_struct{subject_i}.(curr_cond_name)(trial_i).velocities= val;
                saccades_struct{subject_i}.(curr_cond_name)(trial_i).peak_vels= val;
            end   
            
            function eyeballer_save_func(saccades_struct)
                % saves the data handled by an eyeballer session for each subject
                % input:
                %   * saccades_struct -> the saccades data generated with the eyeballer
                for saved_subject_i= 1:numel(obj.subjects_etas)                                                       
                    curr_saccades_analysis_struct.raw_eye_data= raw_eye_data_for_eyeballer{saved_subject_i};
                    curr_saccades_analysis_struct.manual_saccades_search_func_params= manual_saccades_search_func_params_for_eyeballer{saved_subject_i};
                    curr_saccades_analysis_struct.saccades_struct= saccades_struct{saved_subject_i}; 
                    curr_saccades_analysis_struct.eye_data_struct= eye_data_struct{saved_subject_i}; 
                    obj.subjects_etas{saved_subject_i}.registerSaccadesAnalysis(curr_saccades_analysis_struct);
                    obj.subjects_etas{saved_subject_i}.save(etas_full_paths{saved_subject_i});
                end
            end
        end                
    end                
    
    methods (Access= private, Static)         
        function v = vecvel(xx, type, sampling_rate)
            % calculate eyes velocities per sample
            % input:
            %   * xx -> matrix of eye positions.
            %           xx(:,1) - x coordinates. xx(:,2) - y coordinates.
            %   * type -> int representing the algorithm to calculate the velocities with.
            %   * sampling_rate -> the sampling rate of the recording
            %
            % output:
            %   * v -> matrix of velocities
            %          v(:,1) - x axis velocities. v(:,2) - y axis velocities.
            
            N = length(xx); % length of the time series
            %v = zeros(N,2);
            v = zeros(size(xx));            
            switch type
                case 1
                    v(2:N-1,:) = sampling_rate/2*(xx(3:end,:) - xx(1:end-2,:));
                case 2
                    v(3:N-2,:) = sampling_rate/6*(xx(5:end,:) + xx(4:end-1,:) - xx(2:end-3,:) - xx(1:end-4,:));
                    v(2,:) = sampling_rate/2*(xx(3,:) - xx(1,:));
                    v(N-1,:) = sampling_rate/2*(xx(end,:) - xx(end-2,:));
                case 3
                    if sampling_rate == 1000
                        n = 10;
                        Xm2 = (xx(n-9:end-18,:) + xx(n-8:end-17,:) + xx(n-7:end-16,:) + xx(n-6:end-15,:)) / 4;
                        Xm1 = (xx(n-5:end-14,:) + xx(n-4:end-13,:) + xx(n-3:end-12,:) + xx(n-2:end-11,:)) / 4;
                        
                        Xp1 = (xx(n+5:end-4,:) + xx(n+4:end-5,:) + xx(n+3:end-6,:) + xx(n+2:end-7,:)) / 4;
                        Xp2 = (xx(n+9:end-0,:) + xx(n+8:end-1,:) + xx(n+7:end-2,:) + xx(n+6:end-3,:)) / 4;
                        
                        v(n:N-(n-1),:) = (sampling_rate*(Xp2+Xp1-Xm1-Xm2)) / 24;
                        
                        % recursively call the SAMPLING==500 case below, just so I don't have
                        % to write the huge chunk of code. Not ideal practice but isn't too bad
                        % in this case
                        v_strt = vecvel(xx(1:13,:),  500,3)*2;
                        v_end  = vecvel(xx(N-12:N,:),500,3)*2;
                        v(1:9,  :)     = v_strt(1:9,:);
                        v(end-8:end,:) = v_end(end-8:end,:);
                        
                    elseif sampling_rate == 500
                        n = 5;
                        Xm2 = (xx(n-4:end-8,:) + xx(n-3:end-7,:)) / 2;
                        Xm1 = (xx(n-2:end-6,:) + xx(n-1:end-5,:)) / 2;
                        
                        Xp1 = (xx(n+2:end-2,:) + xx(n+1:end-3,:)) / 2;
                        Xp2 = (xx(n+4:end-0,:) + xx(n+3:end-1,:)) / 2;
                        
                        v(n:N-(n-1),:) = (sampling_rate*(Xp2+Xp1-Xm1-Xm2)) / 12;
                        
                        v(3:4,:)     = sampling_rate/6*(xx(5:6,:) + xx(4:5,:) - xx(2:3,:) - xx(1:2,:));
                        v(N-3:N-2,:) = sampling_rate/6*(xx(N-1:N,:) + xx(N-2:N-1,:) - xx(N-4:N-3,:) - xx(N-5:N-4,:));
                        v(2,:)   = sampling_rate/2*(xx(3,:) - xx(1,:));
                        v(N-1,:) = sampling_rate/2*(xx(end,:) - xx(end-2,:));
                        
                        % this is the same above and might be a little easier to read, but avoiding
                        % recursion in Matlab is generally a good idea
                        %             v_strt = vecvel(xx(1:6,:), 500, 2);
                        %             v_end  = vecvel(xx(end-5:end,:), 500,2);
                        %             v(1:4) = v_strt(1:4,:);
                        %             v(end-3:end) = v_end(end-3:end,:);
                    end
            end
        end     
        
        %sac(r,1:2) : [onset offset] of saccade r         
        function [sac, radius]= engbertAlgorithm(vel,VFAC,MINDUR) % MINDUR actually means minimum samples number here
            msdx = sqrt( nanmedian(vel(:,1).^2) - (nanmedian(vel(:,1)))^2 );
            msdy = sqrt( nanmedian(vel(:,2).^2) - (nanmedian(vel(:,2)))^2 );
            if msdx<realmin
                msdx = sqrt( nanmean(vel(:,1).^2) - (nanmean(vel(:,1)))^2 );
                if msdx<realmin
                    throw( MException('microsacc:msdxZero', 'msdx<realmin in microsacc.m') );
                end
            end
            
            if msdy<realmin
                msdy = sqrt( nanmean(vel(:,2).^2) - (nanmean(vel(:,2)))^2 );
                if msdy<realmin
                    throw( MException('microsacc:msdyZero', 'msdy<realmin in microsacc.m') );
                end
            end
            
            radiusx = VFAC*msdx;
            radiusy = VFAC*msdy;
            radius = [radiusx radiusy];
            
            % compute test criterion: ellipse equation
            test = (vel(:,1)/radiusx).^2 + (vel(:,2)/radiusy).^2;
            indx = find(test>1);

            % determine saccades
            N = length(indx); 
            sac = [];
            nsac = 0;
            dur = 1;
            a = 1;
            k = 1;
            while k<N
                if indx(k+1)-indx(k)==1
                    dur = dur + 1;
                else
                    if dur>=MINDUR
                        nsac = nsac + 1;
                        b = k;
                        sac(nsac,:) = [indx(a) indx(b)];
                    end
                    a = k+1;
                    dur = 1;
                end
                k = k + 1;
            end 
            
            if dur>=MINDUR
                nsac = nsac + 1;
                b = k;
                sac(nsac,:) = [indx(a) indx(b)];
            end
        end
        
        %amps(r,1:2) : [dX dY] of saccade r
        function amps= calcSaccadesAmplitudes(x, onsets, offsets)
            saccades_nr= numel(onsets);
            amps= zeros(saccades_nr,2);
            for saccade_i=1:saccades_nr
                i = onsets(saccade_i):offsets(saccade_i);
                [minx, ix1] = min(x(i,1));
                [maxx, ix2] = max(x(i,1));
                [miny, iy1] = min(x(i,2));
                [maxy, iy2] = max(x(i,2));
                dX = sign(ix2-ix1)*(maxx-minx);
                dY = sign(iy2-iy1)*(maxy-miny);
                amps(saccade_i,:) = [dX dY];
            end
        end
                
        function [sacl_revised, sacr_revised, monol, monor, kept_left_is, kept_right_is] = binsacc(sacl, sacr, ampsl, ampsr)            
            if size(sacr,1)*size(sacl,1)>0                
                % determine saccade clusters
                TR = max(sacr(:,2));
                TL = max(sacl(:,2));
                T = max([TL TR]);
                s = zeros(1,T+1);
                for i=1:size(sacl,1)
                    s(sacl(i,1)+1:sacl(i,2)) = 1;
                end
                
                for i=1:size(sacr,1)
                    s(sacr(i,1)+1:sacr(i,2)) = 1;
                end
                
                s(1) = 0;
                s(end) = 0;
                m = find(diff(s~=0));
                N = length(m)/2;
                m = reshape(m,2,N)';
                
                % determine binocular saccades
                NB = 0;
                NR = 0;
                NL = 0;
                sacr_revised= [];
                sacl_revised= [];
                monol = [];
                monor = [];
                kept_left_is= [];
                kept_right_is= [];
                for i=1:N
                    l = find( m(i,1)<=sacl(:,1) & sacl(:,2)<=m(i,2) );
                    r = find( m(i,1)<=sacr(:,1) & sacr(:,2)<=m(i,2) );
                    if length(l)*length(r)>0
                        ampr = sqrt(ampsr(r,1).^2+ampsr(r,2).^2);
                        ampl = sqrt(ampsl(l,1).^2+ampsl(l,2).^2);
                        [h, ir] = max(ampr);
                        [h, il] = max(ampl);
                        NB = NB + 1;
                        kept_right_is(NB)= r(ir);
                        kept_left_is(NB)= l(il);
                        sacr_revised(NB,:) = sacr(r(ir),:) ;
                        sacl_revised(NB,:) = sacl(l(il),:) ;
                    else
                        % determine monocular saccades
                        if length(l)==0
                            NR = NR + 1;
                            monor(NR,:) = sacr(r,:);
                        end
                        
                        if length(r)==0
                            NL = NL + 1;
                            monol(NL,:) = sacl(l,:);
                        end
                    end
                end
            else
                % special cases of exclusively monocular saccades
                if size(sacr,1)==0
                    sacr_revised= [];
                    sacl_revised= [];
                    monor = [];
                    monol = sacl;
                end
                
                if size(sacl,1)==0
                    sacr_revised= [];
                    sacl_revised= [];
                    monol = [];
                    monor = sacr;
                end
            end
        end
        
        function saccade_data= findSaccadeForcefullyOnDefinedTimesByEngbert(eye_data, times)
            mapped_times= mapTimesToValidEyeDataTimeSpace();
            eye_data.left_eye.eye_vels= eye_data.left_eye.eye_vels(eye_data.non_nan_times_logical_vec,:);            
            eye_data.right_eye.eye_vels= eye_data.right_eye.eye_vels(eye_data.non_nan_times_logical_vec,:);
            eye_data.left_eye.baseline_corrected_eye_data= eye_data.left_eye.baseline_corrected_eye_data(eye_data.non_nan_times_logical_vec,:);
            eye_data.right_eye.baseline_corrected_eye_data= eye_data.right_eye.baseline_corrected_eye_data(eye_data.non_nan_times_logical_vec,:);
            [left_eye_onset, left_eye_offset]= findSaccadeTimes(eye_data.left_eye.eye_vels);
            if isempty(left_eye_onset)
                saccade_data= [];
                return;
            end
            
            [right_eye_onset, right_eye_offset]= findSaccadeTimes(eye_data.right_eye.eye_vels);
            if isempty(left_eye_onset)
                saccade_data= [];
                return;
            end
            
            saccade_data.onset = min([right_eye_onset, left_eye_onset]); 
            saccade_data.offset = max([right_eye_offset, left_eye_offset])';
            saccade_data.onset= foundSaccadeTimeToOriginalTimeSpace(saccade_data.onset);
            saccade_data.offset= foundSaccadeTimeToOriginalTimeSpace(saccade_data.offset);            
            
            left_eye_amp= SaccadesExtractor.calcSaccadesAmplitudes(eye_data.left_eye.baseline_corrected_eye_data(mapped_times,:), left_eye_onset, left_eye_offset);
            right_eye_amp= SaccadesExtractor.calcSaccadesAmplitudes(eye_data.right_eye.baseline_corrected_eye_data(mapped_times,:), right_eye_onset, right_eye_offset);                                                                                  
                            
            saccade_data.amplitude = (sqrt(right_eye_amp(:,1).^2+right_eye_amp(:,2).^2)+sqrt(left_eye_amp(:,1).^2+left_eye_amp(:,2).^2))/2;
            DR = right_eye_offset - right_eye_onset + 1;
            DL = left_eye_offset - left_eye_onset + 1;
            saccade_data.duration= (DR+DL)/2;
            saccade_data.delay_between_eyes= right_eye_onset - right_eye_offset;
            saccade_data.direction = atan2((right_eye_amp(:,2)+left_eye_amp(:,2))/2,(right_eye_amp(:,1)+left_eye_amp(:,1))/2);            
            
            left_eye_vels_on_saccade= eye_data.left_eye.eye_vels(left_eye_onset:left_eye_offset, :);
            left_eye_vels_on_saccade_szs = sqrt( left_eye_vels_on_saccade(:,1).^2 + left_eye_vels_on_saccade(:,2).^2 );
            right_eye_vels_on_saccade= eye_data.right_eye.eye_vels(right_eye_onset:right_eye_offset, :);
            right_eye_vels_on_saccade_szs = sqrt( right_eye_vels_on_saccade(:,1).^2 + right_eye_vels_on_saccade(:,2).^2 );
            
            saccade_data.velocity = (mean(left_eye_vels_on_saccade_szs) + mean(right_eye_vels_on_saccade_szs))/2;
            
            left_eye_peak_vel= max(left_eye_vels_on_saccade_szs);
            right_eye_peak_vel= max(right_eye_vels_on_saccade_szs);
            saccade_data.peak_vel= (left_eye_peak_vel + right_eye_peak_vel)/2;                                                                     
            
            function mapped_times= mapTimesToValidEyeDataTimeSpace()                
                pivot_i= floor( (1+numel(times))/2 );
                times_before_pivot= times(1:pivot_i-1);
                good_time_samples_nr= sum(eye_data.non_nan_times_logical_vec(times_before_pivot));
                times_before_pivot_nr= numel(times_before_pivot);
                start_time= times(1);
                while start_time>1 && good_time_samples_nr<times_before_pivot_nr
                    start_time= start_time - 1;
                    good_time_samples_nr= good_time_samples_nr + eye_data.non_nan_times_logical_vec(start_time);
                end                               
                
                times_from_pivot_onwards= times(pivot_i:end);
                good_time_samples_nr= good_time_samples_nr + sum(eye_data.non_nan_times_logical_vec(times_from_pivot_onwards));
                end_time= times(end);
                while end_time<numel(eye_data.non_nan_times_logical_vec) && good_time_samples_nr<numel(times)
                    end_time= end_time + 1;
                    good_time_samples_nr= good_time_samples_nr + eye_data.non_nan_times_logical_vec(end_time);
                end               
                
                if start_time==1
                    mapped_start_time= 1;
                else                    
                    mapped_start_time= sum(eye_data.non_nan_times_logical_vec(1:start_time));
                end                
                mapped_end_time= sum(eye_data.non_nan_times_logical_vec(1:end_time));
                mapped_times= mapped_start_time:mapped_end_time;
            end
            
            function original_time= foundSaccadeTimeToOriginalTimeSpace(found_saccade_time)
                saccade_time_in_valid_data_time_space= found_saccade_time + mapped_times(1) - 1;
                accumulator= 0;
                time= 0;
                while accumulator<saccade_time_in_valid_data_time_space
                    time= time + 1;
                    accumulator= accumulator + eye_data.non_nan_times_logical_vec(time);                    
                end
                
                original_time= time;
            end                                                
            
            function [onset, offset]= findSaccadeTimes(eye_vels)
                msdx = sqrt( nanmedian(eye_vels(mapped_times,1).^2) - (nanmedian(eye_vels(mapped_times,1)))^2 );
                msdy = sqrt( nanmedian(eye_vels(mapped_times,2).^2) - (nanmedian(eye_vels(mapped_times,2)))^2 );

                if msdx<realmin
                    msdx = sqrt( nanmean(eye_vels(mapped_times,1).^2) - (nanmean(eye_vels(mapped_times,1)))^2 );
                    if msdx<realmin
                        throw( MException('microsacc:msdxZero', 'msdx<realmin in microsacc.m') );
                    end
                end

                if msdy<realmin
                    msdy = sqrt( nanmean(eye_vels(mapped_times,1).^2) - (nanmean(eye_vels(mapped_times,1)))^2 );
                    if msdy<realmin
                        throw( MException('microsacc:msdyZero', 'msdy<realmin in microsacc.m') );
                    end
                end

                for vel_threshold= 6:-1:1 % TODO: FIX... the 6 means a total breakdown
                    radiusx = vel_threshold*msdx;
                    radiusy = vel_threshold*msdy;
                    % compute test criterion: ellipse equation
                    test = (eye_vels(mapped_times,1)/radiusx).^2 + (eye_vels(mapped_times,1)/radiusy).^2;
                    saccadic_time_points = find(test>1);
                    if isempty(saccadic_time_points)
                        continue;
                    else
                        onsets_dists_from_mid_time = abs(saccadic_time_points - floor(length(mapped_times)/2));
                        closest_saccadic_time_point_to_mid = saccadic_time_points(onsets_dists_from_mid_time == min(onsets_dists_from_mid_time));
                        curr_tested_time= closest_saccadic_time_point_to_mid + 1;
                        while curr_tested_time<=length(mapped_times) && test(curr_tested_time)>1
                            curr_tested_time= curr_tested_time + 1;
                        end

                        if curr_tested_time>length(mapped_times)
                            continue;
                        else
                            offset= curr_tested_time - 1;  
                            curr_tested_time = closest_saccadic_time_point_to_mid;
                            while curr_tested_time >= 1 && test(curr_tested_time)>1
                                curr_tested_time= curr_tested_time - 1;
                            end
                            
                            if curr_tested_time == 0
                                continue;
                            else
                                onset = curr_tested_time;
                                return;
                            end
                        end
                    end
                end

                %got here if couldnt find a saccade
                onset= [];    
                offset= [];
            end
        end        
    end
end

