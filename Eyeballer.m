%TODO: nest this class inside SaccadesExtractor somehow. 
classdef Eyeballer < handle
    properties (Access= public, Constant)
        ENUM_NO_SACCADE_CODE= 0;
        ENUM_ALGORITHM_GENERATED_SACCADE_CODE= 1;
        ENUM_REJECTED_SACCADE_CODE= 2;
        ENUM_USER_GENERATED_SACCADE_CODE= 3;
        ENUM_MANUAL_BLINK_REJECTED_SACCADE_CODE = 4;                
    end
    
    properties (Access= private, Constant)
        FIG_TITLE= 'Data Inspector';
        AUTO_EXTRACTION_PARAMS_FIG_TITLE= 'New Auto Extraction Parameters';
        LEGEND_PNG_PATH = fullfile('resources', 'eyeballer_legend.png');
        Y_AXIS_ZERO_LINE_SPEC = 'k--';
        AXES_X_RANGE_SIZE= 2000;
        LEFT_EYE_PLOT_COLOR= [0, 125, 128]/255;        
        RIGHT_EYE_PLOT_COLOR= [0, 195, 255]/255;                  
        MANUAL_BLINK_PLOT_COLOR = [255, 0, 255]/255;
        SACCADE_MARKERS_SIZE= 3; 
        HALF_TIME_WINDOW_FOR_MANUAL_SACCADE_SEARCH= 100;
                
        ALGORITHM_GENERATED_SACCADE_COLOR= [0, 209, 24]/255;
        REJECTED_SACCADE_COLOR= [255, 0, 0]/255;
        USER_GENERATED_SACCADE_COLOR= [0, 0, 255]/255;      
        SACCADES_COLORS= [[0, 209, 24]/255; [255, 0, 0]/255; [0, 0, 255]/255; [255, 0, 255]/255];
    end
    
    properties (Access= private)        
        eye_data;
        timeline_left_offset;
        sampling_rates;
        mean_range;   
        std_range;
        manual_saccade_search_func;
        manual_saccade_search_func_input;      
        saccades_detecetion_algorithm_params;
        original_saccades_data;        
        eyeballing_altered_saccades_data;        
        randomization_vec;                
        main_fig_pos;
        main_gui_background_color;
        fig;
        auto_extraction_params_fig;                         
        eyes_x_coords_axes;
        eyes_y_coords_axes;
        curr_displayed_tooltip= [];
        rejection_texts = [];
        curr_subject_editbox;
        curr_trial_editbox;
        pan_obj;
        zoom_obj;        
        curr_subject= 1;
        curr_trial= 1;  
        curr_trial_saccades_plots_hs= {};
        user_undo_stack= {};
        user_redo_stack= {};
        is_eyeballing_accepted= true;   
        save_func;
        pan_hand_icon_cdata;
        zoom_in_icon_cdata;
        zoom_out_icon_cdata;
        was_new_extraction_requested= false;
        new_extraction_params = [];
        auto_extraction_amp_lim_uicontrol;
        auto_extraction_amp_low_lim_uicontrol;
        auto_extraction_vel_threshold_uicontrol;
        min_dur_for_saccade_uicontrol;
        min_dur_between_saccades_uicontrol;
        lowpass_filter_uicontrol;
        is_blink_being_drawn_on_x_axes = 0;
        is_blink_being_drawn_on_y_axes = 0;
        manual_blink_first_t = [];
        blink_curr_marker_h = [];
        blink_start_marker_h = [];
    end
    
    methods (Access= public)
        function obj= Eyeballer(save_func, raw_eye_data, timeline_left_offset, sampling_rates, manual_saccade_search_params, saccades_data, main_fig_pos, main_gui_background_color)   
            subjects_nr= numel(raw_eye_data);            
            obj.eye_data= cell(1, subjects_nr);
            obj.timeline_left_offset = timeline_left_offset;
            obj.sampling_rates = sampling_rates;
            obj.save_func= save_func;          
            obj.manual_saccade_search_func= manual_saccade_search_params.manual_saccade_search_func;  
            obj.manual_saccade_search_func_input= cell(1, subjects_nr);
            obj.saccades_detecetion_algorithm_params = manual_saccade_search_params.saccades_detecetion_algorithm_params;
            obj.original_saccades_data= saccades_data;
            obj.eyeballing_altered_saccades_data= cell(1, subjects_nr);               
            obj.rejection_texts = cell(1, subjects_nr);
            for subject_i= 1:subjects_nr
                curr_subject_conds_names= fieldnames(raw_eye_data{subject_i});
                curr_subject_conds_nr= numel(curr_subject_conds_names);                               
                eye_data_unshuffled= [];  
                manual_saccade_search_func_input_unshuffled= [];
                eyeballing_altered_saccades_data_unshuffled= [];                
                for cond_i= 1:curr_subject_conds_nr                                 
                    eye_data_unshuffled= [eye_data_unshuffled, raw_eye_data{subject_i}.(curr_subject_conds_names{cond_i})]; 
                    manual_saccade_search_func_input_unshuffled= [manual_saccade_search_func_input_unshuffled; ...
                        manual_saccade_search_params.manual_saccade_search_func_input{subject_i}.(curr_subject_conds_names{cond_i})'];                    
                    eyeballing_altered_saccades_data_unshuffled= [eyeballing_altered_saccades_data_unshuffled; ...
                        saccades_data{subject_i}.(curr_subject_conds_names{cond_i})'];                       
                end
                
                if ~isfield(eyeballing_altered_saccades_data_unshuffled, 'user_codes')                    
                    for trial_i= 1:numel(eyeballing_altered_saccades_data_unshuffled)
                        eyeballing_altered_saccades_data_unshuffled(trial_i).user_codes= [];
                        curr_trial_saccades_nr= numel( eyeballing_altered_saccades_data_unshuffled(trial_i).onsets );
                        if curr_trial_saccades_nr > 0
                            eyeballing_altered_saccades_data_unshuffled(trial_i).user_codes= ...
                                Eyeballer.ENUM_ALGORITHM_GENERATED_SACCADE_CODE*ones(1, curr_trial_saccades_nr);
                        end
                    end
                end
                
                if ~isfield(eyeballing_altered_saccades_data_unshuffled, 'is_trial_accepted')
                    for trial_i= 1:numel(eyeballing_altered_saccades_data_unshuffled)
                        eyeballing_altered_saccades_data_unshuffled(trial_i).is_trial_accepted= 1;                        
                    end 
                end
                
                curr_subject_trials_nr= numel(eye_data_unshuffled);
                obj.randomization_vec{subject_i}= 1:curr_subject_trials_nr; %randperm(numel(eye_data_unshuffled));
                obj.eye_data{subject_i}= eye_data_unshuffled(obj.randomization_vec{subject_i});                   
                                                                       
                obj.manual_saccade_search_func_input{subject_i}= manual_saccade_search_func_input_unshuffled(obj.randomization_vec{subject_i});
                obj.eyeballing_altered_saccades_data{subject_i}= eyeballing_altered_saccades_data_unshuffled(obj.randomization_vec{subject_i});                                
                obj.rejection_texts{subject_i} = cell(1, curr_subject_trials_nr);                
                trial_dur_max = 0;                
                for trial_i = 1:curr_subject_trials_nr
                    trial_dur = numel(eye_data_unshuffled(trial_i).non_nan_times_logical_vec);
                    if trial_dur > trial_dur_max
                        trial_dur_max = trial_dur;
                    end
                    obj.eyeballing_altered_saccades_data{subject_i}(trial_i).non_nan_times_logical_vec = double(obj.eye_data{subject_i}(trial_i).non_nan_times_logical_vec);                    
                end                
            end
            
            data_ranges = [];
            for subject_i= 1:subjects_nr
                for trial_i = 1:numel(obj.eye_data{subject_i})
                    data_ranges = [data_ranges, max([abs(obj.eye_data{subject_i}(trial_i).left_x), ...
                                                     abs(obj.eye_data{subject_i}(trial_i).left_y), ...
                                                     abs(obj.eye_data{subject_i}(trial_i).right_x), ...
                                                     abs(obj.eye_data{subject_i}(trial_i).right_y)])];
                end
            end
                
            obj.mean_range = mean(data_ranges);
            obj.std_range = std(data_ranges);
            obj.main_fig_pos= main_fig_pos;
            obj.main_gui_background_color= main_gui_background_color;                                                      
            obj.fig= figure('Visible', 'on', 'name', obj.FIG_TITLE, 'NumberTitle', 'off', 'units', 'pixels', 'Position', obj.main_fig_pos, ...
                'MenuBar', 'none', ...
                'KeyPressFcn', @obj.keyPressCallback, ...
                'WindowButtonMotionFcn', @obj.mouseMovedCallback, ...                
                'color', obj.main_gui_background_color);                                                                                              
            
            obj.pan_obj= pan(obj.fig);
            obj.zoom_obj= zoom(obj.fig);
            loaded_pan_hand_icon_cdata= load(fullfile('resources','pan_hand_icon_cdata.mat'));
            obj.pan_hand_icon_cdata= loaded_pan_hand_icon_cdata.pan_hand_icon_cdata;
            loaded_zoom_in_icon_cdata= load(fullfile('resources','zoom_in_icon_cdata.mat'));
            obj.zoom_in_icon_cdata= loaded_zoom_in_icon_cdata.zoom_in_icon_cdata;
            loaded_zoom_out_icon_cdata= load(fullfile('resources','zoom_out_icon_cdata.mat'));
            obj.zoom_out_icon_cdata= loaded_zoom_out_icon_cdata.zoom_out_icon_cdata;
            
            uicontrol('Style', 'text', 'tag', 'c3001', 'units', 'normalized', ...
                'String', 'X Coordinates', ...
                'Position', [0.05    0.4382    0.1908    0.0406], ...
                'FontSize', 20.0, ...
                'BackgroundColor', obj.main_gui_background_color);            
            uicontrol('Style', 'text', 'tag', 'c3002', 'units', 'normalized', ...
                'String', 'Y Coordinates', ...
                'Position', [0.05    0.9204    0.1908    0.0406], ...
                'FontSize', 20.0, ...
                'BackgroundColor', obj.main_gui_background_color);            
            [legend_img_cdata(:,:,1:3), ~, legend_img_cdata(:,:,4)] = imread(obj.LEGEND_PNG_PATH, 'png');              
            axes('xcolor', obj.main_gui_background_color, 'xtick', [], 'ycolor', obj.main_gui_background_color, 'ytick', [], ...
                 'position', [0.28, 0.4382, 0.5, 0.035], 'Color', obj.main_gui_background_color);            
            image('cdata', legend_img_cdata(end:-1:1, :, 1:3), 'alphadata', legend_img_cdata(end:-1:1, :, 4));
            axes('xcolor', obj.main_gui_background_color, 'xtick', [], 'ycolor', obj.main_gui_background_color, 'ytick', [], ...
                 'position', [0.28, 0.9204, 0.5, 0.035], 'Color', obj.main_gui_background_color);
            image('cdata', legend_img_cdata(end:-1:1, :, 1:3),'alphadata', legend_img_cdata(end:-1:1,:, 4));
            obj.eyes_x_coords_axes= axes('Box', 'on', 'position', [0.05, 0.05, 0.75, 0.38], 'ButtonDownFcn', @obj.eyeCoordsXAxesButtonDownCallback);
            obj.eyes_y_coords_axes= axes('Box', 'on', 'position', [0.05, 0.53, 0.75, 0.38], 'ButtonDownFcn', @obj.eyeCoordsYAxesButtonDownCallback);
            hold(obj.eyes_x_coords_axes);
            hold(obj.eyes_y_coords_axes);                        
             
            obj.plotCurrTrialSaccades(true);
            
            interface_panel= uipanel(obj.fig, 'tag', 'p1', 'units', 'normalized', ...
                'Position',[0.81    0.05   0.17    0.86], ...
                'visible', 'on', ...
                'BackgroundColor', obj.main_gui_background_color);
            
            uicontrol(interface_panel, 'Style', 'text', 'tag', 'c1001', 'units', 'normalized', ...
                'String', 'Current Subject', ...
                'Position', [0.1     0.91353      0.7431      0.0322], ...
                'FontSize', 12.0, ...
                'BackgroundColor', obj.main_gui_background_color);
            
            obj.curr_subject_editbox= uicontrol(interface_panel, 'Style', 'edit', 'units', 'normalized', 'tag', 'c1002', ...
                'String', '1', ...
                'Position', [0.3379     0.84813      0.3229      0.0538], ...
                'callback', @obj.currSubjectEditedCallback);
            
            uicontrol(interface_panel, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c1003', ...
                'String', '<', ...
                'Position', [0.0671     0.84813      0.1927      0.0523], ...
                'FontSize', 10.0, ...
                'BackgroundColor', obj.main_gui_background_color, ...
                'KeyPressFcn', @obj.keyPressCallback, ...
                'callback', @obj.currSubjectReversePressedCallback);
            
            uicontrol(interface_panel, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c1004', ...
                'String', '>', ...
                'Position', [0.739     0.84813      0.1927      0.0523], ...
                'FontSize', 10.0, ...
                'BackgroundColor', obj.main_gui_background_color, ...
                'KeyPressFcn', @obj.keyPressCallback, ...
                'callback', @obj.currSubjectAdvancePressedCallback);
            
            uicontrol(interface_panel, 'Style', 'text', 'tag', 'c1005', 'units', 'normalized', ...
                'String', 'Trial Displayed', ...
                'Position', [0.10643     0.75993      0.7327      0.0424], ...
                'FontSize', 12.0, ...
                'BackgroundColor', obj.main_gui_background_color);
            
            obj.curr_trial_editbox= uicontrol(interface_panel, 'Style', 'edit', 'units', 'normalized', 'tag', 'c1006', ...
                'String', num2str(obj.curr_trial), ...
                'Position', [0.3379      0.7022      0.3229      0.0538], ...
                'callback', @obj.displayedTrialEditedCallback);           
            uicontrol(interface_panel, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c1007', ...
                'String', '<', ...
                'Position', [0.0671      0.7022      0.1927      0.0523], ...
                'FontSize', 10.0, ...
                'BackgroundColor', obj.main_gui_background_color, ...
                'KeyPressFcn', @obj.keyPressCallback, ...
                'callback', @obj.displayedTrialReversePressedCallback);
            
            uicontrol(interface_panel, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c1008', ...
                'String', '>', ...
                'Position', [0.739      0.7022      0.1927      0.0523], ...
                'FontSize', 10.0, ...
                'BackgroundColor', obj.main_gui_background_color, ...
                'KeyPressFcn', @obj.keyPressCallback, ...
                'callback', @obj.displayedTrialAdvancePressedCallback);
                        
            uicontrol(interface_panel, 'Style', 'text', 'tag', 'c1040', 'units', 'normalized', ...
                'String', 'Center On Saccade', ...
                'Position', [0.0965      0.6297       0.809      0.0266], ...
                'FontSize', 12.0, ...
                'BackgroundColor', obj.main_gui_background_color);
            
            uicontrol(interface_panel, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c1041', ...
                'String', '<', ...
                'Position', [0.2516     0.55567      0.1927      0.0523], ...
                'FontSize', 10.0, ...
                'BackgroundColor', obj.main_gui_background_color, ...
                'KeyPressFcn', @obj.keyPressCallback, ...
                'callback', @obj.centerViewOnEarlyerSaccadePressedCallback);
            
            uicontrol(interface_panel, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c1042', ...
                'String', '>', ...
                'Position', [0.5662     0.55567      0.1927      0.0523], ...
                'FontSize', 10.0, ...
                'BackgroundColor', obj.main_gui_background_color, ...
                'KeyPressFcn', @obj.keyPressCallback, ...
                'callback', @obj.centerViewOnLaterSaccadePressedCallback);
                        
            uicontrol(interface_panel, 'Style', 'text', 'tag', 'c1010', 'units', 'normalized', ...
                'String', 'Tools', ...
                'Position', [0.3161     0.47652      0.3473      0.0305], ...
                'FontSize', 12.0, ...
                'BackgroundColor', obj.main_gui_background_color);    
            
            uicontrol(interface_panel, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c1009', ...
                'String', 'Pan', ...
                'Position', [0.0722     0.41682      0.3802      0.0407], ...
                'FontSize', 10.0, ...
                'BackgroundColor', obj.main_gui_background_color, ...
                'callback', @obj.panPressedCallback, ...
                'KeyPressFcn', @obj.keyPressCallback);            
            
            uicontrol(interface_panel, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c1012', ...
                'String', 'Zoom Out', ...
                'Position', [0.5358     0.29762      0.3802      0.0407], ...
                'FontSize', 10.0, ...
                'BackgroundColor', obj.main_gui_background_color, ...
                'callback', @obj.zoomOutPressedCallback, ...
                'KeyPressFcn', @obj.keyPressCallback);
            
            uicontrol(interface_panel, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c1013', ...
                'String', 'Zoom In', ...
                'Position', [0.0722     0.29762      0.3802      0.0407], ...
                'FontSize', 10.0, ...
                'BackgroundColor', obj.main_gui_background_color, ....
                'callback', @obj.zoomInPressedCallback, ...
                'KeyPressFcn', @obj.keyPressCallback);  
            
            uicontrol(interface_panel, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c1020', ...
                'String', 'Select', ...
                'Position', [0.5358     0.41682      0.3802      0.0407], ...
                'FontSize', 10.0, ...
                'BackgroundColor', obj.main_gui_background_color, ....
                'callback', @obj.selectPressedCallback, ...
                'KeyPressFcn', @obj.keyPressCallback);                                                                  
            
            uicontrol(interface_panel, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c1014', ...
                'String', 'Undo', ...
                'Position', [0.0722     0.35812      0.3802      0.0407], ...
                'FontSize', 10.0, ...
                'BackgroundColor', obj.main_gui_background_color, ....
                'callback', @obj.undoPressedCallback, ...
                'KeyPressFcn', @obj.keyPressCallback);
            
            uicontrol(interface_panel, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c1015', ...
                'String', 'Redo', ...
                'Position', [0.5358     0.35812      0.3802      0.0407], ...
                'FontSize', 10.0, ...
                'BackgroundColor', obj.main_gui_background_color, ....
                'callback', @obj.redoPressedCallback, ...
                'KeyPressFcn', @obj.keyPressCallback);
            
            uicontrol(interface_panel, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c1016', ...
                'String', 'Save', ...
                'Position', [0.0590    0.0923    0.3973    0.0509], ...
                'FontSize', 10.0, ...
                'BackgroundColor', obj.main_gui_background_color, ....
                'callback', @obj.savePressedCallback, ...
                'KeyPressFcn', @obj.keyPressCallback);
            
            uicontrol(interface_panel, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c1017', ...
                'String', 'Finish', ...
                'Position', [0.059       0.023      0.3973      0.0509], ...
                'FontSize', 10.0, ...
                'BackgroundColor', obj.main_gui_background_color, ....
                'callback', @obj.finishPressedCallback, ...
                'KeyPressFcn', @obj.keyPressCallback);
            
            uicontrol(interface_panel, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c1018', ...
                'String', 'Cancel', ...
                'Position', [0.5358       0.023      0.3973      0.0509], ...
                'FontSize', 10.0, ...
                'BackgroundColor', obj.main_gui_background_color, ....
                'callback', @obj.cancelPressedCallback, ...
                'KeyPressFcn', @obj.keyPressCallback);
            
            uicontrol(interface_panel, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c2000', ...
                'String', 'Re-extract Saccades', ...
                'Position', [0.0690    0.238    0.8420    0.0509], ...
                'FontSize', 10.0, ...
                'BackgroundColor', obj.main_gui_background_color, ....
                'callback', @obj.autoExtractSaccadesWithNewParamsPressedCallback, ...
                'KeyPressFcn', @obj.keyPressCallback);   
            
            uicontrol(interface_panel, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c3123', ...
                'String', 'Reject-Restore Trial', ...
                'Position', [0.0690    0.182    0.8420    0.0509], ...
                'FontSize', 10.0, ...
                'BackgroundColor', obj.main_gui_background_color, ....
                'callback', @obj.rejectRestoreTrial, ...
                'KeyPressFcn', @obj.keyPressCallback); 
            
            set(obj.fig, 'Visible', 'On');        
        end
        
        function [was_new_extraction_requested, new_extraction_params]= run(obj)              
            set(obj.fig, 'Visible', 'on');   
            %a=b;
            waitfor(obj.fig);                      
            was_new_extraction_requested= obj.was_new_extraction_requested;                        
            if was_new_extraction_requested                
                new_extraction_params = obj.new_extraction_params;                
            else
                new_extraction_params= [];
            end
        end    
        
        function [saccades_struct, eyeballing_session_stats]= getSaccadesStruct(obj)
            subjects_nr= numel(obj.original_saccades_data);                            
            eyeballing_session_stats= cell(1, subjects_nr);
            if obj.is_eyeballing_accepted                 
                saccades_struct= cell(1, subjects_nr);                
                for subject_i= 1:subjects_nr    
                    saccades_struct_fieldnames = fieldnames(obj.eyeballing_altered_saccades_data{subject_i});
                    eyeballing_altered_saccades_data_unshuffled(obj.randomization_vec{subject_i})= obj.eyeballing_altered_saccades_data{subject_i};                                        
                    curr_subject_conds_names= fieldnames(obj.original_saccades_data{subject_i});
                    curr_subject_conds_nr= numel(curr_subject_conds_names); 
                    prev_conds_trials_nr= 0;
                    for cond_i= 1:curr_subject_conds_nr 
                        curr_subject_cond_trials_nr= numel( obj.original_saccades_data{subject_i}.(curr_subject_conds_names{cond_i}) );
                        for trial_i = 1:curr_subject_cond_trials_nr
                            for field_idx = 1:numel(saccades_struct_fieldnames)
                                saccades_struct{subject_i}.(curr_subject_conds_names{cond_i})(trial_i).(saccades_struct_fieldnames{field_idx})= [];
                            end                                               
                        end
                                                
                        eyeballing_session_stats{subject_i}.(curr_subject_conds_names{cond_i}).accepted_saccades_nr= zeros(curr_subject_cond_trials_nr, 1);
                        eyeballing_session_stats{subject_i}.(curr_subject_conds_names{cond_i}).rejected_saccades_nr= zeros(curr_subject_cond_trials_nr, 1);
                        eyeballing_session_stats{subject_i}.(curr_subject_conds_names{cond_i}).user_generated_saccades_nr= zeros(curr_subject_cond_trials_nr, 1);
                        eyeballing_session_stats{subject_i}.(curr_subject_conds_names{cond_i}).blinked_out_saccades_nr= zeros(curr_subject_cond_trials_nr, 1);
                        for trial_i= 1:curr_subject_cond_trials_nr      
                            eyeballing_altered_saccades_data_unshuffled(prev_conds_trials_nr + trial_i).non_nan_times_logical_vec( ...
                                eyeballing_altered_saccades_data_unshuffled(prev_conds_trials_nr + trial_i).non_nan_times_logical_vec == -1) = 0;
                            eyeballing_altered_saccades_data_unshuffled(prev_conds_trials_nr + trial_i).non_nan_times_logical_vec = ...
                                logical(eyeballing_altered_saccades_data_unshuffled(prev_conds_trials_nr + trial_i).non_nan_times_logical_vec);
                            saccades_struct{subject_i}.(curr_subject_conds_names{cond_i})(trial_i)= ...                                    
                                eyeballing_altered_saccades_data_unshuffled(prev_conds_trials_nr + trial_i);
                            if obj.eyeballing_altered_saccades_data{subject_i}(prev_conds_trials_nr + trial_i).is_trial_accepted                                
                                if ~isempty( eyeballing_altered_saccades_data_unshuffled(prev_conds_trials_nr + trial_i).user_codes )
                                    eyeballing_session_stats{subject_i}.(curr_subject_conds_names{cond_i}).accepted_saccades_nr(trial_i)= ...
                                        sum( eyeballing_altered_saccades_data_unshuffled(prev_conds_trials_nr + trial_i).user_codes == obj.ENUM_ALGORITHM_GENERATED_SACCADE_CODE );
                                    eyeballing_session_stats{subject_i}.(curr_subject_conds_names{cond_i}).rejected_saccades_nr(trial_i)= ...
                                        sum( eyeballing_altered_saccades_data_unshuffled(prev_conds_trials_nr + trial_i).user_codes == obj.ENUM_REJECTED_SACCADE_CODE );
                                    eyeballing_session_stats{subject_i}.(curr_subject_conds_names{cond_i}).user_generated_saccades_nr(trial_i)= ...
                                        sum( eyeballing_altered_saccades_data_unshuffled(prev_conds_trials_nr + trial_i).user_codes == obj.ENUM_USER_GENERATED_SACCADE_CODE );                            
                                    eyeballing_session_stats{subject_i}.(curr_subject_conds_names{cond_i}).blinked_out_saccades_nr(trial_i)= ...
                                        sum( eyeballing_altered_saccades_data_unshuffled(prev_conds_trials_nr + trial_i).user_codes == obj.ENUM_MANUAL_BLINK_REJECTED_SACCADE_CODE );
                                end
%                             else
%                                 for field_idx = 1:numel(saccades_struct_fieldnames)
%                                     saccades_struct{subject_i}.(curr_subject_conds_names{cond_i})(trial_i).(saccades_struct_fieldnames{field_idx})= NaN;
%                                 end  
%                                 eyeballing_session_stats{subject_i}.(curr_subject_conds_names{cond_i}).accepted_saccades_nr(trial_i)= NaN;
%                                 eyeballing_session_stats{subject_i}.(curr_subject_conds_names{cond_i}).rejected_saccades_nr(trial_i)= NaN;
%                                 eyeballing_session_stats{subject_i}.(curr_subject_conds_names{cond_i}).user_generated_saccades_nr(trial_i)= NaN;
%                                 eyeballing_session_stats{subject_i}.(curr_subject_conds_names{cond_i}).blinked_out_saccades_nr(trial_i)= NaN;
                            end
                        end
                        
                        prev_conds_trials_nr= prev_conds_trials_nr + curr_subject_cond_trials_nr;
                    end                                
                end                
            else
                saccades_struct= obj.original_saccades_data;
                for subject_i= 1:subjects_nr
                    curr_subject_conds_names= fieldnames(obj.original_saccades_data{subject_i});
                    curr_subject_conds_nr= numel(curr_subject_conds_names); 
                    for cond_i= 1:curr_subject_conds_nr 
                        curr_subject_cond_trials_nr= numel( obj.original_saccades_data{subject_i}.(curr_subject_conds_names{cond_i}) );
                        eyeballing_session_stats{subject_i}.(curr_subject_conds_names{cond_i}).rejected_microsaccades_nr= ...
                            zeros(curr_subject_cond_trials_nr, 1);
                        eyeballing_session_stats{subject_i}.(curr_subject_conds_names{cond_i}).user_marked_microsaccades_nr= ...
                            zeros(curr_subject_cond_trials_nr, 1);  
                        eyeballing_session_stats{subject_i}.(curr_subject_conds_names{cond_i}).accepted_microsaccades_nr= ...
                            zeros(curr_subject_cond_trials_nr, 1);
                        for trial_i= 1:curr_subject_cond_trials_nr  
                            if ~isempty( obj.original_saccades_data{subject_i}.(curr_subject_conds_names{cond_i})(trial_i).onsets ) && all( ~isnan(obj.original_saccades_data{subject_i}.(curr_subject_conds_names{cond_i})(trial_i).onsets) )                               
                                eyeballing_session_stats{subject_i}.(curr_subject_conds_names{cond_i}).accepted_microsaccades_nr(trial_i)= ...
                                    numel(obj.original_saccades_data{subject_i}.(curr_subject_conds_names{cond_i})(trial_i).onsets);                                                        
                            end
                        end
                    end
                end
            end                        
        end
    end
              
    methods (Access= private)                        
        function plotCurrTrialSaccades(obj, do_axes_lims_reset)  
            delete(obj.blink_curr_marker_h);
            obj.blink_curr_marker_h = [];
            delete(obj.blink_start_marker_h);
            obj.blink_start_marker_h = [];
            if isempty(obj.eye_data{obj.curr_subject})
                return;
            end
            
            set(obj.fig, 'name', [obj.FIG_TITLE, ' - Loading Trial...']);                        
            disp('loading trial');
            curr_subject_trial_eye_data_struct= obj.eye_data{obj.curr_subject}(obj.curr_trial);
            cla(obj.eyes_x_coords_axes);
            cla(obj.eyes_y_coords_axes); 
            obj.curr_displayed_tooltip= [];
            if ~obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).is_trial_accepted
                obj.rejection_texts{obj.curr_subject}{obj.curr_trial} = [text(sum(get(obj.eyes_x_coords_axes, 'XLim'))/2, sum(get(obj.eyes_x_coords_axes, 'YLim'))/2, 'REJECTED', 'parent', obj.eyes_x_coords_axes, 'Color', [1, 0, 0], 'FontSize', 20), ...
                                                                         text(sum(get(obj.eyes_y_coords_axes, 'XLim'))/2, sum(get(obj.eyes_y_coords_axes, 'YLim'))/2, 'REJECTED', 'parent', obj.eyes_y_coords_axes, 'Color', [1, 0, 0], 'FontSize', 20)];            
            end
            trial_dur = numel(curr_subject_trial_eye_data_struct.non_nan_times_logical_vec); % * 1000 / obj.sampling_rates;
            if trial_dur == 0
                set(obj.fig, 'name', obj.FIG_TITLE);   
                disp('no recorded data. loading done.');
                return;
            end

            if do_axes_lims_reset
                set(obj.eyes_x_coords_axes, 'XLim', [0, min(obj.AXES_X_RANGE_SIZE, trial_dur)] - obj.timeline_left_offset);
                set(obj.eyes_y_coords_axes, 'XLim', [0, min(obj.AXES_X_RANGE_SIZE, trial_dur)] - obj.timeline_left_offset);        
            end
            plot(obj.eyes_x_coords_axes, (0:min(obj.AXES_X_RANGE_SIZE, trial_dur)) - obj.timeline_left_offset, zeros(1,min(obj.AXES_X_RANGE_SIZE, trial_dur) + 1), '--', 'color', [0 0 0]);
            plot(obj.eyes_y_coords_axes, (0:min(obj.AXES_X_RANGE_SIZE, trial_dur)) - obj.timeline_left_offset, zeros(1,min(obj.AXES_X_RANGE_SIZE, trial_dur) + 1), '--', 'color', [0 0 0]);
            
            data_times_vec= find(obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).non_nan_times_logical_vec == 1);
            manual_blink_times_vec= find(obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).non_nan_times_logical_vec == -1);
            blink_times_vec = find(obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).non_nan_times_logical_vec == 0);
            if isempty(data_times_vec) && isempty(manual_blink_times_vec)
                [no_data_on_x_plot, no_data_on_y_plot] = plotBlinkSeg(1:trial_dur);                
            else
                no_data_on_x_plot = [];                                                
                [data_segs_start_times, data_segs_end_times] = extractSegsStartAndEndTimes(data_times_vec);                
                [manual_blink_segs_start_times, manual_blink_segs_end_times] = extractSegsStartAndEndTimes(manual_blink_times_vec);                
                [blink_segs_start_times, blink_segs_end_times] = extractSegsStartAndEndTimes(blink_times_vec);                                
                for seg_i= 1:numel(data_segs_end_times)
                    data_seg_times= data_segs_start_times(seg_i):data_segs_end_times(seg_i);
                    [x_ax_left_eye_plot, x_ax_right_eye_plot, y_ax_left_eye_plot, y_ax_right_eye_plot] = plotEyeDataSeg(data_seg_times, obj.LEFT_EYE_PLOT_COLOR, obj.RIGHT_EYE_PLOT_COLOR, '-', @obj.eyeDataPlotBtnDownCallback);
                end                        

                for seg_i= 1:numel(manual_blink_segs_end_times)
                    manual_blink_seg_times= manual_blink_segs_start_times(seg_i):manual_blink_segs_end_times(seg_i);
                    [x_ax_left_eye_plot, x_ax_right_eye_plot, y_ax_left_eye_plot, y_ax_right_eye_plot] = plotEyeDataSeg(manual_blink_seg_times, obj.MANUAL_BLINK_PLOT_COLOR, obj.MANUAL_BLINK_PLOT_COLOR, ':', []);
                end  
                
                for seg_i= 1:numel(blink_segs_end_times)
                    blink_seg_times= blink_segs_start_times(seg_i):blink_segs_end_times(seg_i);
                    [no_data_on_x_plot, no_data_on_y_plot] = plotBlinkSeg(blink_seg_times);
                end                                                
                               
                curr_subject_trial_saccades_data= obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial);
                curr_subject_trial_saccades_nr= numel(curr_subject_trial_saccades_data.onsets);  
                obj.curr_trial_saccades_plots_hs= {};
                for saccade_i= 1:curr_subject_trial_saccades_nr
                    curr_saccade_onset= curr_subject_trial_saccades_data.onsets(saccade_i);                
                    curr_saccade_offset= curr_subject_trial_saccades_data.offsets(saccade_i);
                    saccades_valid_domain= find(obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).non_nan_times_logical_vec == 1 | obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).non_nan_times_logical_vec == -1);                    
                    saccade_times= saccades_valid_domain(find(saccades_valid_domain==curr_saccade_onset):find(saccades_valid_domain==curr_saccade_offset));                                
                    obj.curr_trial_saccades_plots_hs{end+1}= obj.plotSaccade(saccade_times, obj.SACCADES_COLORS(curr_subject_trial_saccades_data.user_codes(saccade_i),:));
                end
            end
                        
            if do_axes_lims_reset
                set(obj.eyes_x_coords_axes, 'YLim', obj.mean_range + 4*obj.std_range*[-1,1]);
                set(obj.eyes_y_coords_axes, 'YLim', obj.mean_range + 4*obj.std_range*[-1,1]);        
            end
            set(obj.fig, 'name', obj.FIG_TITLE);
                                                
            disp('Done.');
            
            function [segs_start_times, segs_end_times] = extractSegsStartAndEndTimes(time_vec)
                if isempty(time_vec)
                    segs_start_times = [];
                    segs_end_times = [];
                else
                    segs_end_times_is= find(diff(time_vec)>1); 
                    segs_start_times= [time_vec(1), time_vec(segs_end_times_is+1)];
                    segs_end_times= [time_vec(segs_end_times_is), time_vec(end)];    
                end
            end
            
            function [plot_x_ax_left_eye_plot, plot_x_ax_right_eye_plot, plot_y_ax_left_eye_plot, plot_y_ax_right_eye_plot] = plotEyeDataSeg(times, left_eye_plot_color, right_eye_plot_color, line_desc, btn_down_fcn)        
                plot_x_ax_left_eye_plot = plot(obj.eyes_x_coords_axes, times - obj.timeline_left_offset, curr_subject_trial_eye_data_struct.left_x(times), line_desc, 'color', left_eye_plot_color,  'ButtonDownFcn', btn_down_fcn);
                plot_x_ax_right_eye_plot = plot(obj.eyes_x_coords_axes, times - obj.timeline_left_offset, curr_subject_trial_eye_data_struct.right_x(times), line_desc, 'color', right_eye_plot_color, 'ButtonDownFcn', btn_down_fcn);            
                plot_y_ax_left_eye_plot = plot(obj.eyes_y_coords_axes, times - obj.timeline_left_offset, curr_subject_trial_eye_data_struct.left_y(times), line_desc, 'color', left_eye_plot_color, 'ButtonDownFcn', btn_down_fcn);                            
                plot_y_ax_right_eye_plot = plot(obj.eyes_y_coords_axes, times - obj.timeline_left_offset, curr_subject_trial_eye_data_struct.right_y(times), line_desc, 'color', right_eye_plot_color, 'ButtonDownFcn', btn_down_fcn);                           
            end
            
            function [blinks_on_x_plot, blinks_on_y_plot] = plotBlinkSeg(times)
                if 1<times(1) && times(end)<numel(curr_subject_trial_eye_data_struct.left_x)
                    xAxisLeftEyeStartY = curr_subject_trial_eye_data_struct.left_x(times(1)-1);
                    xAxisLeftEyeEndY = curr_subject_trial_eye_data_struct.left_x(times(end)+1);
                    xAxisRightEyeStartY = curr_subject_trial_eye_data_struct.right_x(times(1)-1);
                    xAxisRightEyeEndY = curr_subject_trial_eye_data_struct.right_x(times(end)+1);
                    yAxisLeftEyeStartY = curr_subject_trial_eye_data_struct.left_y(times(1)-1);
                    yAxisLeftEyeEndY = curr_subject_trial_eye_data_struct.left_y(times(end)+1);
                    yAxisRightEyeStartY = curr_subject_trial_eye_data_struct.right_y(times(1)-1);                    
                    yAxisRightEyeEndY = curr_subject_trial_eye_data_struct.right_y(times(end)+1);  
                elseif 1<times(1)
                    xAxisLeftEyeStartY = curr_subject_trial_eye_data_struct.left_x(times(1)-1);
                    xAxisLeftEyeEndY = xAxisLeftEyeStartY;
                    xAxisRightEyeStartY = curr_subject_trial_eye_data_struct.right_x(times(1)-1);
                    xAxisRightEyeEndY = xAxisRightEyeStartY;
                    yAxisLeftEyeStartY = curr_subject_trial_eye_data_struct.left_y(times(1)-1);
                    yAxisLeftEyeEndY = yAxisLeftEyeStartY;
                    yAxisRightEyeStartY = curr_subject_trial_eye_data_struct.right_y(times(1)-1);                    
                    yAxisRightEyeEndY = yAxisRightEyeStartY;
                elseif times(end)<numel(curr_subject_trial_eye_data_struct.left_x)
                    xAxisLeftEyeEndY = curr_subject_trial_eye_data_struct.left_x(times(end)+1);
                    xAxisLeftEyeStartY = xAxisLeftEyeEndY;
                    xAxisRightEyeEndY = curr_subject_trial_eye_data_struct.right_x(times(end)+1);
                    xAxisRightEyeStartY = xAxisRightEyeEndY;
                    yAxisLeftEyeEndY = curr_subject_trial_eye_data_struct.left_y(times(end)+1);
                    yAxisLeftEyeStartY = yAxisLeftEyeEndY;
                    yAxisRightEyeEndY = curr_subject_trial_eye_data_struct.right_y(times(end)+1);
                    yAxisRightEyeStartY = yAxisRightEyeEndY;
                else
                    blinks_on_x_plot = [];
                    blinks_on_y_plot = [];
                    return;
                end
                              
                blinks_on_x_plot = plot(obj.eyes_x_coords_axes, [times(1), times(end)] - obj.timeline_left_offset, [xAxisLeftEyeStartY, xAxisLeftEyeEndY], 'k:', 'markersize', 5);
                plot(obj.eyes_x_coords_axes, [times(1), times(end)] - obj.timeline_left_offset, [xAxisRightEyeStartY, xAxisRightEyeEndY], 'k:', 'markersize', 5);
                blinks_on_y_plot = plot(obj.eyes_y_coords_axes, [times(1), times(end)] - obj.timeline_left_offset, [yAxisLeftEyeStartY, yAxisLeftEyeEndY], 'k:', 'markersize', 5);                
                plot(obj.eyes_y_coords_axes, [times(1), times(end)] - obj.timeline_left_offset, [yAxisRightEyeStartY, yAxisRightEyeEndY], 'k:', 'markersize', 5);                
            end                        
        end                                
        
        function saccade_plots_hs= plotSaccade(obj, saccade_times, plot_color)                        
            curr_subject_trial_eye_data_struct= obj.eye_data{obj.curr_subject}(obj.curr_trial);
            saccade_onset= saccade_times(1);                       
            eye_data_on_saccade_onset_vec= [curr_subject_trial_eye_data_struct.left_x(saccade_onset), ...
                curr_subject_trial_eye_data_struct.right_x(saccade_onset), ...
                curr_subject_trial_eye_data_struct.left_y(saccade_onset), ...
                curr_subject_trial_eye_data_struct.right_y(saccade_onset)];
            start_marks_hs= plotEdgeMark(saccade_onset, eye_data_on_saccade_onset_vec);
            
            saccade_offset= saccade_times(end);
            eye_data_on_saccade_offset_vec= [curr_subject_trial_eye_data_struct.left_x(saccade_offset), ...
                curr_subject_trial_eye_data_struct.right_x(saccade_offset), ...
                curr_subject_trial_eye_data_struct.left_y(saccade_offset), ...
                curr_subject_trial_eye_data_struct.right_y(saccade_offset)];
            end_marks_hs= plotEdgeMark(saccade_offset, eye_data_on_saccade_offset_vec);
                                    
            saccade_segs_end_times_is= find(diff(saccade_times)>1);
            saccade_segs_start_times= [saccade_onset, saccade_times(saccade_segs_end_times_is+1)];
            saccade_segs_end_times= [saccade_times(saccade_segs_end_times_is), saccade_offset];
            segs_nr= numel(saccade_segs_start_times);
            saccade_plots_hs= zeros(1, 4*segs_nr + 8); %last 8 slots are for the saccade's start marks' plots and end marks' plots
            for saccade_seg_i= 1:segs_nr
                saccade_seg_times= saccade_segs_start_times(saccade_seg_i):saccade_segs_end_times(saccade_seg_i);
                saccade_seg_eye_data= [curr_subject_trial_eye_data_struct.left_x(saccade_seg_times); ...
                    curr_subject_trial_eye_data_struct.right_x(saccade_seg_times); ...
                    curr_subject_trial_eye_data_struct.left_y(saccade_seg_times); ...
                    curr_subject_trial_eye_data_struct.right_y(saccade_seg_times)];
                saccade_plots_hs( (saccade_seg_i-1)*4 + (1:4) )= plotEyeDataOnSaccadeSeg(saccade_seg_times, saccade_seg_eye_data);                
            end
            
            saccade_plots_hs(4*segs_nr + (1:4))= start_marks_hs;
            saccade_plots_hs(4*segs_nr + (5:8))= end_marks_hs;
            for saccade_plot_h_i= 1:numel(saccade_plots_hs)
                set(saccade_plots_hs(saccade_plot_h_i), 'UserData', saccade_onset);
            end                                 
            
            function p= plotEdgeMark(time, eye_data)
                p= zeros(1,4);                
                p([1,2])= plot(obj.eyes_x_coords_axes, time - obj.timeline_left_offset, [eye_data(1), eye_data(2)], ...
                    'LineStyle', 'none', ...
                    'marker', 'o', ...
                    'markerSize', obj.SACCADE_MARKERS_SIZE, ...
                    'MarkerEdgeColor', plot_color, ...
                    'ButtonDownFcn', @obj.saccadePlotBtnDownCallback);
                        
                p([3,4])= plot(obj.eyes_y_coords_axes, time - obj.timeline_left_offset, [eye_data(3), eye_data(4)], ...
                    'LineStyle', 'none', ...
                    'marker', 'o', ...
                    'markerSize', obj.SACCADE_MARKERS_SIZE, ...
                    'MarkerEdgeColor', plot_color, ...
                    'ButtonDownFcn', @obj.saccadePlotBtnDownCallback);
            end
            
            function p= plotEyeDataOnSaccadeSeg(saccade_seg_times, eye_data)
                p= zeros(1,4);     
                p([1,2])= plot(obj.eyes_x_coords_axes, [saccade_seg_times; saccade_seg_times]' - obj.timeline_left_offset, eye_data([1,2],:)', ...
                    'LineStyle', '-', ...
                    'LineWidth', 2, ...
                    'Color', plot_color, ...
                    'ButtonDownFcn', @obj.saccadePlotBtnDownCallback);
                
                p([3,4])= plot(obj.eyes_y_coords_axes, [saccade_seg_times; saccade_seg_times]' - obj.timeline_left_offset, eye_data([3,4],:)', ...
                    'LineStyle', '-', ...
                    'LineWidth', 2, ...
                    'Color', plot_color, ...
                    'ButtonDownFcn', @obj.saccadePlotBtnDownCallback);
            end
        end                
        
        function eyeCoordsXAxesButtonDownCallback(obj, ~, ~) 
            if (~obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).is_trial_accepted || ...
                isempty(obj.eye_data{obj.curr_subject}) || ... 
                numel(obj.eye_data{obj.curr_subject}(obj.curr_trial).non_nan_times_logical_vec) == 0)
                return;
            end
            point_on_axes= get(gca, 'CurrentPoint');
            curr_mouse_pos_x= ceil(point_on_axes(1) + obj.timeline_left_offset);
            if curr_mouse_pos_x <= 0
                return;
            end
            if obj.is_blink_being_drawn_on_x_axes                                
                if obj.manual_blink_first_t < curr_mouse_pos_x
                    blinked_out_start_t = obj.manual_blink_first_t;
                    blinked_out_end_t = curr_mouse_pos_x;                
                else
                    blinked_out_start_t = curr_mouse_pos_x;
                    blinked_out_end_t = obj.manual_blink_first_t;                    
                end                                
                
                set(obj.fig, 'Pointer', 'arrow');        
                if strcmp(get(obj.fig, 'SelectionType'), 'normal')                                       
                    obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).non_nan_times_logical_vec(blinked_out_start_t:blinked_out_end_t) = -abs(obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).non_nan_times_logical_vec(blinked_out_start_t:blinked_out_end_t));
                    curr_subject_trial_saccades_data = obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial);
                    blinked_out_saccades_logical_vec = curr_subject_trial_saccades_data.onsets < blinked_out_end_t & blinked_out_start_t < curr_subject_trial_saccades_data.offsets;
                    saccades_user_codes = obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).user_codes'; 
                    obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).user_codes(blinked_out_saccades_logical_vec & (saccades_user_codes == obj.ENUM_ALGORITHM_GENERATED_SACCADE_CODE | saccades_user_codes == obj.ENUM_REJECTED_SACCADE_CODE))= obj.ENUM_MANUAL_BLINK_REJECTED_SACCADE_CODE;
                    blinked_out_user_saccades_logical_vec = blinked_out_saccades_logical_vec & obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).user_codes' == obj.ENUM_USER_GENERATED_SACCADE_CODE;                    
                    if any(blinked_out_user_saccades_logical_vec)
                        Eyeballer.clearSaccadePlots([obj.curr_trial_saccades_plots_hs{blinked_out_user_saccades_logical_vec}]);
                        if ~isempty(obj.curr_displayed_tooltip)
                            delete(obj.curr_displayed_tooltip)
                            obj.curr_displayed_tooltip= [];
                        end                    
                        obj.curr_trial_saccades_plots_hs(blinked_out_user_saccades_logical_vec)= [];
                        cleared_data= obj.clearSaccadeData(blinked_out_user_saccades_logical_vec);                                                                                   
                    end
                else
                    obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).non_nan_times_logical_vec(blinked_out_start_t:blinked_out_end_t) = abs(obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).non_nan_times_logical_vec(blinked_out_start_t:blinked_out_end_t));
                    curr_subject_trial_saccades_data = obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial);
                    obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).user_codes(blinked_out_start_t < curr_subject_trial_saccades_data.onsets & curr_subject_trial_saccades_data.offsets < blinked_out_end_t & curr_subject_trial_saccades_data.user_codes' == obj.ENUM_MANUAL_BLINK_REJECTED_SACCADE_CODE)= obj.ENUM_ALGORITHM_GENERATED_SACCADE_CODE;
                end                
                obj.is_blink_being_drawn_on_x_axes = false;
                obj.plotCurrTrialSaccades(false);
            else
                if obj.is_blink_being_drawn_on_y_axes
                    delete(obj.blink_curr_marker_h);
                    delete(obj.blink_start_marker_h); 
                    obj.is_blink_being_drawn_on_y_axes = false;
                end                
                obj.manual_blink_first_t = curr_mouse_pos_x;
                obj.blink_curr_marker_h = plot(obj.eyes_x_coords_axes, [curr_mouse_pos_x, curr_mouse_pos_x] - obj.timeline_left_offset, obj.mean_range + 4*obj.std_range*[-1,1], '-b');
                set(obj.blink_curr_marker_h, 'ButtonDownFcn', @obj.eyeCoordsXAxesButtonDownCallback);
                obj.blink_start_marker_h = plot(obj.eyes_x_coords_axes, [curr_mouse_pos_x, curr_mouse_pos_x] - obj.timeline_left_offset, obj.mean_range + 4*obj.std_range*[-1,1], '-b');
                set(obj.blink_start_marker_h, 'ButtonDownFcn', @obj.eyeCoordsXAxesButtonDownCallback);
                set(obj.fig, 'Pointer', 'cross');
                obj.is_blink_being_drawn_on_x_axes = true;
            end
        end
        
        function eyeCoordsYAxesButtonDownCallback(obj, ~, ~)      
            if (~obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).is_trial_accepted || ...
                isempty(obj.eye_data{obj.curr_subject}) || ... 
                numel(obj.eye_data{obj.curr_subject}(obj.curr_trial).non_nan_times_logical_vec) == 0)
                return;
            end
            point_on_axes= get(gca, 'CurrentPoint');
            curr_mouse_pos_x= ceil(point_on_axes(1) + obj.timeline_left_offset);
            if curr_mouse_pos_x <= 0
                return;
            end
            if obj.is_blink_being_drawn_on_y_axes                                
                if obj.manual_blink_first_t < curr_mouse_pos_x
                    blinked_out_start_t = obj.manual_blink_first_t;
                    blinked_out_end_t = curr_mouse_pos_x;                
                else
                    blinked_out_start_t = curr_mouse_pos_x;
                    blinked_out_end_t = obj.manual_blink_first_t;                    
                end                               
                set(obj.fig, 'Pointer', 'arrow'); 
                if strcmp(get(obj.fig, 'SelectionType'), 'normal')
                    obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).non_nan_times_logical_vec(blinked_out_start_t:blinked_out_end_t) = -abs(obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).non_nan_times_logical_vec(blinked_out_start_t:blinked_out_end_t));
                    curr_subject_trial_saccades_data = obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial);                    
                    blinked_out_saccades_logical_vec = curr_subject_trial_saccades_data.onsets < blinked_out_end_t & blinked_out_start_t < curr_subject_trial_saccades_data.offsets;                    
                    saccades_user_codes = obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).user_codes'; 
                    obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).user_codes(blinked_out_saccades_logical_vec & (saccades_user_codes == obj.ENUM_ALGORITHM_GENERATED_SACCADE_CODE | saccades_user_codes == obj.ENUM_REJECTED_SACCADE_CODE))= obj.ENUM_MANUAL_BLINK_REJECTED_SACCADE_CODE;
                    blinked_out_user_saccades_logical_vec = blinked_out_saccades_logical_vec & obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).user_codes' == obj.ENUM_USER_GENERATED_SACCADE_CODE;                    
                    if any(blinked_out_user_saccades_logical_vec)
                        Eyeballer.clearSaccadePlots([obj.curr_trial_saccades_plots_hs{blinked_out_user_saccades_logical_vec}]);
                        if ~isempty(obj.curr_displayed_tooltip)
                            delete(obj.curr_displayed_tooltip)
                            obj.curr_displayed_tooltip= [];
                        end                    
                        obj.curr_trial_saccades_plots_hs(blinked_out_user_saccades_logical_vec)= [];
                        cleared_data= obj.clearSaccadeData(blinked_out_user_saccades_logical_vec);
                    end
                else
                    obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).non_nan_times_logical_vec(blinked_out_start_t:blinked_out_end_t) = abs(obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).non_nan_times_logical_vec(blinked_out_start_t:blinked_out_end_t));
                    curr_subject_trial_saccades_data = obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial);
                    obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).user_codes(blinked_out_start_t < curr_subject_trial_saccades_data.onsets & curr_subject_trial_saccades_data.offsets < blinked_out_end_t & curr_subject_trial_saccades_data.user_codes' == obj.ENUM_MANUAL_BLINK_REJECTED_SACCADE_CODE)= obj.ENUM_ALGORITHM_GENERATED_SACCADE_CODE;
                end
                obj.is_blink_being_drawn_on_y_axes = false;
                obj.plotCurrTrialSaccades(false);
            else
                if obj.is_blink_being_drawn_on_x_axes
                    delete(obj.blink_curr_marker_h);
                    delete(obj.blink_start_marker_h); 
                    obj.is_blink_being_drawn_on_x_axes = false;
                end                
                obj.manual_blink_first_t = curr_mouse_pos_x;
                obj.blink_curr_marker_h = plot(obj.eyes_y_coords_axes, [curr_mouse_pos_x, curr_mouse_pos_x] - obj.timeline_left_offset, obj.mean_range + 4*obj.std_range*[-1,1], '-b');
                set(obj.blink_curr_marker_h, 'ButtonDownFcn', @obj.eyeCoordsYAxesButtonDownCallback);
                obj.blink_start_marker_h = plot(obj.eyes_y_coords_axes, [curr_mouse_pos_x, curr_mouse_pos_x] - obj.timeline_left_offset, obj.mean_range + 4*obj.std_range*[-1,1], '-b');
                set(obj.blink_start_marker_h, 'ButtonDownFcn', @obj.eyeCoordsYAxesButtonDownCallback);
                set(obj.fig, 'Pointer', 'cross');
                obj.is_blink_being_drawn_on_y_axes = true;
            end
        end                
        
        function eyeDataPlotBtnDownCallback(obj, ~, ~)
            if (~obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).is_trial_accepted)
                return;
            end
            obj.user_redo_stack= {};
            point_on_axes= get(gca, 'CurrentPoint');
            curr_mouse_pos_x= floor(point_on_axes(1) + obj.timeline_left_offset);            
            saccade_search_times= ...
                max( 1, curr_mouse_pos_x - obj.HALF_TIME_WINDOW_FOR_MANUAL_SACCADE_SEARCH ) : ...
                min( length(obj.eye_data{obj.curr_subject}(obj.curr_trial).left_x), curr_mouse_pos_x + obj.HALF_TIME_WINDOW_FOR_MANUAL_SACCADE_SEARCH);                             
            saccade_data= obj.manual_saccade_search_func(obj.manual_saccade_search_func_input{obj.curr_subject}(obj.curr_trial), saccade_search_times);  %TODO: must improve this mechanism                                                                     
            if ~isempty(saccade_data)   
                if ismember(saccade_data.onset, obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).onsets)
                    return;
                end
                
                obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).onsets= ...
                    [obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).onsets; saccade_data.onset];
                obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).offsets= ...
                    [obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).offsets; saccade_data.offset];
                obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).durations= ...
                    [obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).durations; saccade_data.duration];
                obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).delays_between_eyes= ...
                    [obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).delays_between_eyes; saccade_data.delay_between_eyes];
                obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).amplitudes= ...
                    [obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).amplitudes; saccade_data.amplitude];
                obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).directions= ...
                    [obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).directions; saccade_data.direction];
                obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).velocities= ...
                    [obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).velocities; saccade_data.velocity];
                obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).peak_vels= ...
                    [obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).peak_vels; saccade_data.peak_vel];
                obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).user_codes= ...
                    [ obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).user_codes, Eyeballer.ENUM_USER_GENERATED_SACCADE_CODE];                                          
                                
                obj.curr_trial_saccades_plots_hs{end+1}= obj.plotSaccade(saccade_data.onset:saccade_data.offset, obj.USER_GENERATED_SACCADE_COLOR);       
                obj.user_undo_stack= [obj.user_undo_stack, {[obj.ENUM_NO_SACCADE_CODE, obj.curr_subject, obj.curr_trial, ...
                                      saccade_data.onset, saccade_data.offset, saccade_data.duration, ...
                                      saccade_data.delay_between_eyes, saccade_data.amplitude, ...
                                      saccade_data.direction, saccade_data.velocity, saccade_data.peak_vel]}];            
            end
        end
        
        function saccadePlotBtnDownCallback(obj, hObject, ~) 
            if (~obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).is_trial_accepted)
                return;
            end
            obj.user_redo_stack= {};
            curr_saccade_onset= get(hObject,'UserData');                    
            curr_saccade_i= find( obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).onsets==curr_saccade_onset );            
            switch obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).user_codes(curr_saccade_i)
                case obj.ENUM_REJECTED_SACCADE_CODE                    
                    Eyeballer.changeSaccadePlotsColors(obj.curr_trial_saccades_plots_hs{curr_saccade_i}, obj.ALGORITHM_GENERATED_SACCADE_COLOR);
                    obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).user_codes(curr_saccade_i)= obj.ENUM_ALGORITHM_GENERATED_SACCADE_CODE;                                        
                    obj.user_undo_stack= [obj.user_undo_stack, {[obj.ENUM_REJECTED_SACCADE_CODE, obj.curr_subject, obj.curr_trial, curr_saccade_i]}];
                case obj.ENUM_ALGORITHM_GENERATED_SACCADE_CODE      
                    Eyeballer.changeSaccadePlotsColors(obj.curr_trial_saccades_plots_hs{curr_saccade_i}, obj.REJECTED_SACCADE_COLOR);                    
                    obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).user_codes(curr_saccade_i)= obj.ENUM_REJECTED_SACCADE_CODE;                                        
                    obj.user_undo_stack= [obj.user_undo_stack, {[obj.ENUM_ALGORITHM_GENERATED_SACCADE_CODE, obj.curr_subject, obj.curr_trial, curr_saccade_i]}];
                case obj.ENUM_USER_GENERATED_SACCADE_CODE                    
                    Eyeballer.clearSaccadePlots(obj.curr_trial_saccades_plots_hs{curr_saccade_i});
                    if ~isempty(obj.curr_displayed_tooltip)
                        delete(obj.curr_displayed_tooltip)
                        obj.curr_displayed_tooltip= [];
                    end                    
                    obj.curr_trial_saccades_plots_hs(curr_saccade_i)= [];
                    cleared_data= obj.clearSaccadeData(curr_saccade_i);                    
                    obj.user_undo_stack= [obj.user_undo_stack, {[obj.ENUM_USER_GENERATED_SACCADE_CODE, obj.curr_subject, obj.curr_trial, cleared_data]}];                    
            end                        
        end                                         
                    
        function currSubjectEditedCallback(obj, hObject, ~)
            input= get(hObject,'string');
            if Eyeballer.isStrAValidPositiveInteger(input)
                requested_subject= str2double(input);
                if requested_subject>numel(obj.eye_data)
                    set(hObject,'string', num2str(obj.curr_subject));
                else
                    obj.curr_subject= requested_subject;
                    obj.plotCurrTrialSaccades(true);
                end
            else
                set(hObject,'string', num2str(obj.curr_subject));
            end                        
        end
        
        function currSubjectReversePressedCallback(obj, ~, ~)
            obj.updateCurrSubject(obj.curr_subject-1);
            obj.plotCurrTrialSaccades(true);            
        end
        
        function currSubjectAdvancePressedCallback(obj, ~, ~)
            obj.updateCurrSubject(obj.curr_subject+1);
            obj.plotCurrTrialSaccades(true);            
        end
                
        function updateCurrSubject(obj, new_subject_i)
            if new_subject_i~=obj.curr_subject && new_subject_i>=1 && new_subject_i<=numel(obj.eye_data)
                obj.curr_subject= new_subject_i;
                set(obj.curr_subject_editbox, 'string', num2str(new_subject_i));                
            end                        
        end
        
        function displayedTrialEditedCallback(obj, hObject, ~)
            input= get(hObject,'string');
            if Eyeballer.isStrAValidPositiveInteger(input)
                requested_trial= str2double(input);
                if requested_trial>numel(obj.eye_data{obj.curr_subject})
                    set(hObject,'string', num2str(obj.curr_trial));
                else
                    obj.curr_trial= requested_trial;
                    obj.plotCurrTrialSaccades(true);
                end
            else
                set(hObject,'string', num2str(obj.curr_trial));
            end                        
        end
        
        function displayedTrialReversePressedCallback(obj, ~, ~)
            obj.updateCurrTrial(obj.curr_trial - 1);
            obj.plotCurrTrialSaccades(true);            
        end
        
        function displayedTrialAdvancePressedCallback(obj, hObject, ~)
            obj.updateCurrTrial(obj.curr_trial + 1);
            obj.plotCurrTrialSaccades(true);                
        end        
        
        function centerViewOnEarlyerSaccadePressedCallback(obj, ~, ~)    
            if isempty(obj.eyeballing_altered_saccades_data{obj.curr_subject})
                return;
            end
            
            curr_view_center= mean(get(obj.eyes_x_coords_axes, 'XLim'));
            curr_subject_trial_offsets= obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).offsets;     
            earlyer_saccade_offset= max(curr_subject_trial_offsets(curr_subject_trial_offsets<curr_view_center));
            if isempty(earlyer_saccade_offset)
                return;
            end 
            
            earlyer_saccade_i= find(curr_subject_trial_offsets==earlyer_saccade_offset, 1);                                    
            earlyer_saccade_onset= obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).onsets(earlyer_saccade_i);
            earlyer_saccade_offset= curr_subject_trial_offsets(earlyer_saccade_i);
            obj.centerAxesViewOnTime(mean([earlyer_saccade_onset,earlyer_saccade_offset]));            
        end
              
        function centerViewOnLaterSaccadePressedCallback(obj, ~, ~)
            if (isempty(obj.eyeballing_altered_saccades_data{obj.curr_subject}))
                return;
            end
            
            curr_view_center= mean(get(obj.eyes_x_coords_axes, 'XLim'));
            curr_subject_trial_onsets= obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).onsets;
            later_saccade_onset= min(curr_subject_trial_onsets(curr_subject_trial_onsets>curr_view_center));
            if isempty(later_saccade_onset)
                return;
            end
            
            later_saccade_i= find(curr_subject_trial_onsets==later_saccade_onset, 1);                        
            later_saccade_onset= curr_subject_trial_onsets(later_saccade_i);
            later_saccade_offset= obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).offsets(later_saccade_i);
            obj.centerAxesViewOnTime(mean([later_saccade_onset,later_saccade_offset]));                            
        end
                        
        function updateCurrTrial(obj, new_trial_i)                            
            if new_trial_i~=obj.curr_trial && new_trial_i>=1 && new_trial_i<=numel(obj.eye_data{obj.curr_subject})
                obj.curr_trial= new_trial_i;
                set(obj.curr_trial_editbox, 'string', num2str(new_trial_i));                
            end
        end
                  
        function panPressedCallback(obj, ~, ~)            
            set(obj.zoom_obj, 'enable', 'off');
            set(obj.pan_obj, 'Enable', 'on');  
            set(obj.fig, 'pointer', 'custom');
            set(obj.fig, 'pointershapecdata', obj.pan_hand_icon_cdata);
%             zoom_in_icon_cdata= get(obj.fig, 'pointershapecdata')
%             save('zoom_in_icon_cdata.mat', 'zoom_in_icon_cdata');            
        end
        
        function zoomOutPressedCallback(obj, ~, ~)            
            set(obj.pan_obj, 'Enable', 'off');
            set(obj.zoom_obj, 'enable', 'on', 'direction', 'out'); 
            set(obj.fig, 'pointer', 'custom');
            set(obj.fig, 'pointershapecdata', obj.zoom_out_icon_cdata);
%              pan_hand_icon_cdata= get(obj.fig, 'pointershapecdata')
%              save('pan_hand_icon_cdata.mat', 'pan_hand_icon_cdata');            
        end
        
        function zoomInPressedCallback(obj, ~, ~)           
            set(obj.pan_obj, 'Enable', 'off');
            set(obj.zoom_obj, 'enable', 'on', 'direction', 'in');
            set(obj.fig, 'pointer', 'custom');
            set(obj.fig, 'pointershapecdata', obj.zoom_in_icon_cdata);
%             zoom_out_icon_cdata= get(obj.fig, 'pointershapecdata')
%             save('zoom_out_icon_cdata.mat', 'zoom_out_icon_cdata');            
        end
              
        function selectPressedCallback(obj, ~, ~)
            set(obj.pan_obj, 'Enable', 'off');
            set(obj.zoom_obj, 'Enable', 'off');             
        end
        
        function undoPressedCallback(obj, ~, ~)
            if isempty(obj.user_undo_stack)
                return;
            end
            if (~obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).is_trial_accepted)
                return;
            end
            
            %altering the data base part
            last_action_subject_i= obj.user_undo_stack{end}(2);            
            last_action_trial_i= obj.user_undo_stack{end}(3); 
            was_trial_changed= last_action_subject_i~=obj.curr_subject || last_action_trial_i~=obj.curr_trial;
            obj.updateCurrSubject(last_action_subject_i);
            obj.updateCurrTrial(last_action_trial_i);           
            action_to_perform= obj.user_undo_stack{end}(1);             
            if action_to_perform==obj.ENUM_ALGORITHM_GENERATED_SACCADE_CODE || action_to_perform==obj.ENUM_REJECTED_SACCADE_CODE
                saccade_i= obj.user_undo_stack{end}(4);
                concerned_saccade_onset_of_the_undo= obj.eyeballing_altered_saccades_data{last_action_subject_i}(last_action_trial_i).onsets(saccade_i);
                concerned_saccade_offset_of_the_undo= obj.eyeballing_altered_saccades_data{last_action_subject_i}(last_action_trial_i).offsets(saccade_i);
                obj.eyeballing_altered_saccades_data{last_action_subject_i}(last_action_trial_i).user_codes(saccade_i)= action_to_perform;
                if action_to_perform==obj.ENUM_ALGORITHM_GENERATED_SACCADE_CODE                    
                    action_to_perform_on_redo= obj.ENUM_REJECTED_SACCADE_CODE;
                else                    
                    action_to_perform_on_redo= obj.ENUM_ALGORITHM_GENERATED_SACCADE_CODE;
                end
            elseif action_to_perform==obj.ENUM_USER_GENERATED_SACCADE_CODE
                concerned_saccade_onset_of_the_undo= obj.user_undo_stack{end}(4);
                obj.eyeballing_altered_saccades_data{last_action_subject_i}(last_action_trial_i).onsets(end+1)= concerned_saccade_onset_of_the_undo;                    
                concerned_saccade_offset_of_the_undo= obj.user_undo_stack{end}(5);
                obj.eyeballing_altered_saccades_data{last_action_subject_i}(last_action_trial_i).offsets(end+1)= concerned_saccade_offset_of_the_undo;                    
                obj.eyeballing_altered_saccades_data{last_action_subject_i}(last_action_trial_i).durations(end+1)= obj.user_undo_stack{end}(6);                    
                obj.eyeballing_altered_saccades_data{last_action_subject_i}(last_action_trial_i).delays_between_eyes(end+1)= obj.user_undo_stack{end}(7);                    
                obj.eyeballing_altered_saccades_data{last_action_subject_i}(last_action_trial_i).amplitudes(end+1)= obj.user_undo_stack{end}(8);                    
                obj.eyeballing_altered_saccades_data{last_action_subject_i}(last_action_trial_i).directions(end+1)= obj.user_undo_stack{end}(9);
                obj.eyeballing_altered_saccades_data{last_action_subject_i}(last_action_trial_i).velocities(end+1)= obj.user_undo_stack{end}(10);
                obj.eyeballing_altered_saccades_data{last_action_subject_i}(last_action_trial_i).peak_vels(end+1)= obj.user_undo_stack{end}(11);                
                obj.eyeballing_altered_saccades_data{last_action_subject_i}(last_action_trial_i).user_codes(end+1)= Eyeballer.ENUM_USER_GENERATED_SACCADE_CODE;                                
                action_to_perform_on_redo= obj.ENUM_NO_SACCADE_CODE;                
            else
                saccade_i= find(obj.user_undo_stack{end}(4)==obj.eyeballing_altered_saccades_data{last_action_subject_i}(last_action_trial_i).onsets,1);
                concerned_saccade_onset_of_the_undo= obj.eyeballing_altered_saccades_data{last_action_subject_i}(last_action_trial_i).onsets(saccade_i);
                concerned_saccade_offset_of_the_undo= obj.eyeballing_altered_saccades_data{last_action_subject_i}(last_action_trial_i).offsets(saccade_i);
                obj.clearSaccadeData(saccade_i);                
                action_to_perform_on_redo= obj.ENUM_USER_GENERATED_SACCADE_CODE;
            end
                                    
            %altering the graphics part
            if was_trial_changed
                obj.plotCurrTrialSaccades(true);
            elseif action_to_perform==obj.ENUM_ALGORITHM_GENERATED_SACCADE_CODE
                Eyeballer.changeSaccadePlotsColors(obj.curr_trial_saccades_plots_hs{saccade_i}, obj.ALGORITHM_GENERATED_SACCADE_COLOR);                
            elseif action_to_perform==obj.ENUM_REJECTED_SACCADE_CODE
                Eyeballer.changeSaccadePlotsColors(obj.curr_trial_saccades_plots_hs{saccade_i}, obj.REJECTED_SACCADE_COLOR);                
            elseif action_to_perform==obj.ENUM_USER_GENERATED_SACCADE_CODE
                obj.curr_trial_saccades_plots_hs{end+1}= obj.plotSaccade(concerned_saccade_onset_of_the_undo:concerned_saccade_offset_of_the_undo, obj.USER_GENERATED_SACCADE_COLOR);                
            else                
                Eyeballer.clearSaccadePlots(obj.curr_trial_saccades_plots_hs{saccade_i});
                obj.curr_trial_saccades_plots_hs(saccade_i)= [];
            end
            
            obj.user_redo_stack= [obj.user_redo_stack, {[action_to_perform_on_redo, obj.user_undo_stack{end}(2:end)]}];
            obj.user_undo_stack= obj.user_undo_stack(1:end-1);                        
            obj.centerAxesViewOnTime( round((concerned_saccade_onset_of_the_undo+concerned_saccade_offset_of_the_undo)/2) );                        
        end
                
        function redoPressedCallback(obj, ~, ~)            
            if isempty(obj.user_redo_stack)
                return;
            end
            if (~obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).is_trial_accepted)
                return;
            end
            
            %altering the data base part
            last_undone_action_subject_i= obj.user_redo_stack{end}(2);            
            last_undone_action_trial_i= obj.user_redo_stack{end}(3); 
            was_trial_changed= last_undone_action_subject_i~=obj.curr_subject || last_undone_action_trial_i~=obj.curr_trial;
            obj.updateCurrSubject(last_undone_action_subject_i);
            obj.updateCurrTrial(last_undone_action_trial_i);                        
            action_to_perform= obj.user_redo_stack{end}(1);
            if action_to_perform==obj.ENUM_ALGORITHM_GENERATED_SACCADE_CODE || action_to_perform==obj.ENUM_REJECTED_SACCADE_CODE
                saccade_i= obj.user_redo_stack{end}(4);
                concerned_saccade_onset_of_the_redo= obj.eyeballing_altered_saccades_data{last_undone_action_subject_i}(last_undone_action_trial_i).onsets(saccade_i);
                concerned_saccade_offset_of_the_redo= obj.eyeballing_altered_saccades_data{last_undone_action_subject_i}(last_undone_action_trial_i).offsets(saccade_i);
                obj.eyeballing_altered_saccades_data{last_undone_action_subject_i}(last_undone_action_trial_i).user_codes(saccade_i)= action_to_perform;
                if action_to_perform==obj.ENUM_ALGORITHM_GENERATED_SACCADE_CODE
                    action_to_perform_on_undo= obj.ENUM_REJECTED_SACCADE_CODE;
                else
                    action_to_perform_on_undo= obj.ENUM_ALGORITHM_GENERATED_SACCADE_CODE;
                end
            elseif action_to_perform==obj.ENUM_USER_GENERATED_SACCADE_CODE
                concerned_saccade_onset_of_the_redo= obj.user_redo_stack{end}(4);
                obj.eyeballing_altered_saccades_data{last_undone_action_subject_i}(last_undone_action_trial_i).onsets(end+1)= concerned_saccade_onset_of_the_redo;                    
                concerned_saccade_offset_of_the_redo= obj.user_redo_stack{end}(5);
                obj.eyeballing_altered_saccades_data{last_undone_action_subject_i}(last_undone_action_trial_i).offsets(end+1)= concerned_saccade_offset_of_the_redo;                    
                obj.eyeballing_altered_saccades_data{last_undone_action_subject_i}(last_undone_action_trial_i).durations(end+1)= obj.user_redo_stack{end}(6);                    
                obj.eyeballing_altered_saccades_data{last_undone_action_subject_i}(last_undone_action_trial_i).delays_between_eyes(end+1)= obj.user_redo_stack{end}(7);                    
                obj.eyeballing_altered_saccades_data{last_undone_action_subject_i}(last_undone_action_trial_i).amplitudes(end+1)= obj.user_redo_stack{end}(8);                    
                obj.eyeballing_altered_saccades_data{last_undone_action_subject_i}(last_undone_action_trial_i).directions(end+1)= obj.user_redo_stack{end}(9);                    
                obj.eyeballing_altered_saccades_data{last_undone_action_subject_i}(last_undone_action_trial_i).velocities(end+1)= obj.user_redo_stack{end}(10);
                obj.eyeballing_altered_saccades_data{last_undone_action_subject_i}(last_undone_action_trial_i).peak_vels(end+1)= obj.user_redo_stack{end}(11);                    
                obj.eyeballing_altered_saccades_data{last_undone_action_subject_i}(last_undone_action_trial_i).user_codes(end+1)= Eyeballer.ENUM_USER_GENERATED_SACCADE_CODE;                    
                action_to_perform_on_undo= obj.ENUM_NO_SACCADE_CODE;
            else
                saccade_i= find(obj.user_redo_stack{end}(4)==obj.eyeballing_altered_saccades_data{last_undone_action_subject_i}(last_undone_action_trial_i).onsets,1);
                concerned_saccade_onset_of_the_redo= obj.eyeballing_altered_saccades_data{last_undone_action_subject_i}(last_undone_action_trial_i).onsets(saccade_i);
                concerned_saccade_offset_of_the_redo= obj.eyeballing_altered_saccades_data{last_undone_action_subject_i}(last_undone_action_trial_i).offsets(saccade_i);
                obj.clearSaccadeData(saccade_i);                
                action_to_perform_on_undo= obj.ENUM_USER_GENERATED_SACCADE_CODE;
            end
                                   
            %altering the graphics part
            if was_trial_changed
                obj.plotCurrTrialSaccades(true);
            elseif action_to_perform==obj.ENUM_ALGORITHM_GENERATED_SACCADE_CODE
                Eyeballer.changeSaccadePlotsColors(obj.curr_trial_saccades_plots_hs{saccade_i}, obj.ALGORITHM_GENERATED_SACCADE_COLOR);                
            elseif action_to_perform==obj.ENUM_REJECTED_SACCADE_CODE
                Eyeballer.changeSaccadePlotsColors(obj.curr_trial_saccades_plots_hs{saccade_i}, obj.REJECTED_SACCADE_COLOR);  
            elseif action_to_perform==obj.ENUM_USER_GENERATED_SACCADE_CODE
                obj.curr_trial_saccades_plots_hs{end+1}= obj.plotSaccade(concerned_saccade_onset_of_the_redo:concerned_saccade_offset_of_the_redo, obj.USER_GENERATED_SACCADE_COLOR);  
            else
                Eyeballer.clearSaccadePlots(obj.curr_trial_saccades_plots_hs{saccade_i});
                obj.curr_trial_saccades_plots_hs(saccade_i)= [];
            end
            
            obj.user_undo_stack= [obj.user_undo_stack, {[action_to_perform_on_undo, obj.user_redo_stack{end}(2:end)]}];            
            obj.user_redo_stack= obj.user_redo_stack(1:end-1);                                                            
            obj.centerAxesViewOnTime( round((concerned_saccade_onset_of_the_redo+concerned_saccade_offset_of_the_redo)/2) );                        
        end
        
        function cleared_data= clearSaccadeData(obj, saccade_i)
            saccade_parameters_names= setdiff(fieldnames(obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial)), {'is_trial_accepted', 'non_nan_times_logical_vec'});
            cleared_data= cell(1, numel(saccade_parameters_names));
            for saccade_parameter_i= 1:numel(saccade_parameters_names)
                cleared_data{saccade_parameter_i}= ...
                    obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).(saccade_parameters_names{saccade_parameter_i})(saccade_i);
                obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).(saccade_parameters_names{saccade_parameter_i})(saccade_i)= [];
            end
        end
        
        function centerAxesViewOnTime(obj, time)            
            trial_dur= numel(obj.eye_data{obj.curr_subject}(obj.curr_trial).left_x);  
            if obj.AXES_X_RANGE_SIZE<trial_dur
                set(obj.eyes_x_coords_axes, 'XLim', time + floor([-obj.AXES_X_RANGE_SIZE, obj.AXES_X_RANGE_SIZE]/2));
                set(obj.eyes_y_coords_axes, 'XLim', time + floor([-obj.AXES_X_RANGE_SIZE, obj.AXES_X_RANGE_SIZE]/2));
            end
        end
                          
        function savePressedCallback(obj, ~, ~)
            set(obj.fig, 'name', [obj.FIG_TITLE, ' - Saving...']);
            disp('Saving...');
            [saccades_data, ~]= obj.getSaccadesStruct();
            obj.save_func(saccades_data);
            set(obj.fig, 'name', obj.FIG_TITLE);
            disp('Done.');            
        end
                            
        function finishPressedCallback(obj, ~, ~)
            close(obj.fig);
        end
        
        function cancelPressedCallback(obj, ~, ~)
            obj.is_eyeballing_accepted= false;
            close(obj.fig);
        end 
                              
        function autoExtractSaccadesWithNewParamsPressedCallback(obj, ~, ~)
            auto_extraction_params_fig_width= 0.7*obj.main_fig_pos(3);
            auto_extraction_params_fig_height= 0.5*obj.main_fig_pos(4);
            auto_extraction_params_fig_pos_x= obj.main_fig_pos(1)+0.5*(obj.main_fig_pos(3)-auto_extraction_params_fig_width);
            auto_extraction_params_fig_pos_y= obj.main_fig_pos(2)+0.5*(obj.main_fig_pos(4)-auto_extraction_params_fig_height);
            auto_extraction_params_fig_pos= [auto_extraction_params_fig_pos_x, auto_extraction_params_fig_pos_y, ...
                                            auto_extraction_params_fig_width, auto_extraction_params_fig_height];                                        
            obj.auto_extraction_params_fig= figure('Visible', 'off', 'name', obj.AUTO_EXTRACTION_PARAMS_FIG_TITLE, 'NumberTitle', 'off', 'units', 'pixels', 'Position', auto_extraction_params_fig_pos, ...
                'MenuBar', 'none', ...                
                'color', obj.main_gui_background_color);                                                                      
                                                                                                                                      
            uicontrol(obj.auto_extraction_params_fig, 'Style', 'text', 'tag', 'c2001', 'units', 'normalized', ...
                'String', 'Amplitude Upper Limit (deg)', ...
                'Position', [0.066694     0.86501      0.4557    0.06562], ...
                'FontSize', 12.0, ...
                'BackgroundColor', obj.main_gui_background_color);
                     
            obj.auto_extraction_amp_lim_uicontrol= uicontrol(obj.auto_extraction_params_fig, 'Style', 'edit', 'units', 'normalized', 'tag', 'c2002', ...
                'String', obj.saccades_detecetion_algorithm_params.amp_lim, ...
                'Position', [0.7221     0.86387      0.0543     0.08106], ...
                'callback', {@Eyeballer.newExtractionParamEditedCallback, @Eyeballer.isStrAPositiveRealNumber});
            
            uicontrol(obj.auto_extraction_params_fig, 'Style', 'text', 'tag', 'c2013', 'units', 'normalized', ...
                'String', 'Amplitude Lower Limit (deg)', ...
                'Position', [0.067525     0.76015      0.4557    0.06403], ...
                'FontSize', 12.0, ...
                'BackgroundColor', obj.main_gui_background_color);
                        
            obj.auto_extraction_amp_low_lim_uicontrol= uicontrol(obj.auto_extraction_params_fig, 'Style', 'edit', 'units', 'normalized', 'tag', 'c2014', ...
                'String', obj.saccades_detecetion_algorithm_params.amp_low_lim, ...
                'Position', [0.7221     0.75312      0.0543     0.08106], ...
                'callback', {@Eyeballer.newExtractionParamEditedCallback, @Eyeballer.isStrAValidNonNegativeReal});
            
            uicontrol(obj.auto_extraction_params_fig, 'Style', 'text', 'tag', 'c2003', 'units', 'normalized', ...
                'String', 'Eye Velocity Threshold For A Saccade (deg/ms)', ...
                'Position', [0.069144     0.64815      0.4557    0.057501], ...
                'FontSize', 12.0, ...
                'BackgroundColor', obj.main_gui_background_color);
                        
            obj.auto_extraction_vel_threshold_uicontrol= uicontrol(obj.auto_extraction_params_fig, 'Style', 'edit', 'units', 'normalized', 'tag', 'c2004', ...
                'String', obj.saccades_detecetion_algorithm_params.vel_threshold, ...
                'Position', [0.7221      0.6425      0.0543     0.08106], ...
                'callback', {@Eyeballer.newExtractionParamEditedCallback, @Eyeballer.isStrAPositiveRealNumber});
                        
            uicontrol(obj.auto_extraction_params_fig, 'Style', 'text', 'tag', 'c2005', 'units', 'normalized', ...
                'String', 'minimum duration for a saccade (ms)', ...
                'Position', [0.070617     0.43292     0.45574    0.048762], ...
                'FontSize', 12.0, ...
                'BackgroundColor', obj.main_gui_background_color);
                        
            obj.min_dur_for_saccade_uicontrol= uicontrol(obj.auto_extraction_params_fig, 'Style', 'edit', 'units', 'normalized', 'tag', 'c2006', ...
                'String', obj.saccades_detecetion_algorithm_params.saccade_dur_min, ...
                'Position', [0.72208      0.4179     0.05433     0.08106], ...
                'callback', {@Eyeballer.newExtractionParamEditedCallback, @Eyeballer.isStrAValidPositiveInteger});
                                                
            uicontrol(obj.auto_extraction_params_fig, 'Style', 'text', 'tag', 'c2007', 'units', 'normalized', ...
                'String', 'minimum time between saccades (ms)', ...
                'Position', [0.070096     0.55242     0.45574    0.039904], ...
                'FontSize', 12.0, ...
                'BackgroundColor', obj.main_gui_background_color);
            
            obj.min_dur_between_saccades_uicontrol= uicontrol(obj.auto_extraction_params_fig, 'Style', 'edit', 'units', 'normalized', 'tag', 'c2008', ...
                'String', obj.saccades_detecetion_algorithm_params.frequency_max, ...
                'Position', [0.72208     0.52917     0.05433     0.08106], ...
                'callback', {@Eyeballer.newExtractionParamEditedCallback, @Eyeballer.isStrAValidPositiveInteger});                                           
            
            uicontrol(obj.auto_extraction_params_fig, 'Style', 'text', 'tag', 'c2009', 'units', 'normalized', ...
                'String', 'lowpass filter (hz)', ...
                'Position', [0.064367      0.3237     0.45574    0.043831], ...
                'FontSize', 12.0, ...
                'BackgroundColor', obj.main_gui_background_color);
            
            obj.lowpass_filter_uicontrol= uicontrol(obj.auto_extraction_params_fig, 'Style', 'edit', 'units', 'normalized', 'tag', 'c2010', ...
                'String', obj.saccades_detecetion_algorithm_params.low_pass_filter, ...
                'Position', [0.72208      0.3035     0.05433     0.08106], ...
                'callback', {@Eyeballer.newExtractionParamEditedCallback, @Eyeballer.isStrAValidPositiveInteger});
                                    
            uicontrol(obj.auto_extraction_params_fig, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c2011', ...
                'String', 'Go', ...
                'Position', [0.1243    0.066469      0.3176      0.1734], ...
                'FontSize', 12.0, ...
                'BackgroundColor', obj.main_gui_background_color, ....
                'callback', @obj.startNewExtractionPressedCallback);
            
            uicontrol(obj.auto_extraction_params_fig, 'Style', 'pushbutton', 'units', 'normalized', 'tag', 'c2012', ...
                'String', 'Cancel', ...
                'Position', [0.58294      0.066469      0.3176      0.1734], ...
                'FontSize', 12.0, ...
                'BackgroundColor', obj.main_gui_background_color, ....
                'callback', @obj.cancelNewExtractionPressedCallback);
            
            set(obj.auto_extraction_params_fig, 'visible', 'on');          
        end
        
        function startNewExtractionPressedCallback(obj, ~, ~)
            obj.was_new_extraction_requested= true;                        
            auto_extraction_amp_lim= str2double(get(obj.auto_extraction_amp_lim_uicontrol, 'string'));
            if isempty(auto_extraction_amp_lim)
                errordlg('missing amplitude upper limit');
                return;
            end
                        
            auto_extraction_amp_low_lim= str2double(get(obj.auto_extraction_amp_low_lim_uicontrol, 'string'));
            if isempty(auto_extraction_amp_low_lim)
                errordlg('missing amplitude lower limit');
                return;
            end
            
            auto_extraction_vel_threshold= str2double(get(obj.auto_extraction_vel_threshold_uicontrol, 'string'));
            if isempty(auto_extraction_vel_threshold)
                errordlg('missing velocity threshold');
                return;
            end
            
            min_dur_for_saccade = str2double(get(obj.min_dur_for_saccade_uicontrol, 'string'));
            if isempty(min_dur_for_saccade)
                errordlg('missing minimum duration for a saccade');
                return;                
            end
            
            min_dur_between_saccades = str2double(get(obj.min_dur_between_saccades_uicontrol, 'string'));
            if isempty(min_dur_between_saccades)
                errordlg('missing minimum duration between saccades');
                return;                
            end
            
            low_pass_filter = str2double(get(obj.lowpass_filter_uicontrol, 'string'));
            if isempty(low_pass_filter)
                errordlg('missing low pass filter');
                return;                
            end
            
            obj.new_extraction_params.amp_lim = auto_extraction_amp_lim;
            obj.new_extraction_params.amp_low_lim = auto_extraction_amp_low_lim;
            obj.new_extraction_params.vel_threshold = auto_extraction_vel_threshold;
            obj.new_extraction_params.min_dur_for_saccade = min_dur_for_saccade;
            obj.new_extraction_params.min_dur_between_saccades = min_dur_between_saccades;
            obj.new_extraction_params.low_pass_filter = low_pass_filter;
            close(obj.fig);
            close(obj.auto_extraction_params_fig);
        end
        
        function cancelNewExtractionPressedCallback(obj, ~, ~)
            close(obj.auto_extraction_params_fig);
        end        
        
        function mouseMovedCallback(obj, ~, ~)
            if isempty(obj.eye_data{obj.curr_subject})
                return;
            end
            if ~isempty(obj.curr_displayed_tooltip)
                delete(obj.curr_displayed_tooltip)
                obj.curr_displayed_tooltip= [];
            end 
            
            fig_pos= get(obj.fig,'position');
            curr_fig_point= get(obj.fig, 'CurrentPoint');            
            curr_fig_point_x_normalized= curr_fig_point(1,1)/fig_pos(3);
            curr_fig_point_y_normalized= curr_fig_point(1,2)/fig_pos(4);
            x_coords_axes_position= get(obj.eyes_x_coords_axes, 'position');  
            y_coords_axes_position= get(obj.eyes_y_coords_axes, 'position');               
            is_pointer_on_x_coords_axes= x_coords_axes_position(1) < curr_fig_point_x_normalized && ...
                                         curr_fig_point_x_normalized<(x_coords_axes_position(1) + x_coords_axes_position(3)) && ...
                                         x_coords_axes_position(2) < curr_fig_point_y_normalized && ...
                                         curr_fig_point_y_normalized<(x_coords_axes_position(2) + x_coords_axes_position(4));
            is_pointer_on_y_coords_axes= y_coords_axes_position(1) < curr_fig_point_x_normalized && ...
                                         curr_fig_point_x_normalized<(y_coords_axes_position(1) + y_coords_axes_position(3)) && ...
                                         y_coords_axes_position(2) < curr_fig_point_y_normalized && ...
                                         curr_fig_point_y_normalized<(y_coords_axes_position(2) + y_coords_axes_position(4));            
            if is_pointer_on_x_coords_axes
                curr_axes= obj.eyes_x_coords_axes;
            elseif is_pointer_on_y_coords_axes
                curr_axes= obj.eyes_y_coords_axes;
            else
                return;
            end
                                      
            curr_axes_point= get(curr_axes, 'CurrentPoint');
            curr_axes_point_x= ceil(curr_axes_point(1,1)) + obj.timeline_left_offset;
            curr_axes_point_y= curr_axes_point(1,2);
            curr_subject_trial_eye_data_struct= obj.eye_data{obj.curr_subject}(obj.curr_trial);
            epsilon= 0.18*diff(get(curr_axes, 'YLim'));
            if 1<=curr_axes_point_x && curr_axes_point_x<=numel(curr_subject_trial_eye_data_struct.left_x)
                if isCursorCloseToPlot()
                    pointed_saccade_i= find( obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).onsets<=curr_axes_point_x & ...
                        curr_axes_point_x<=obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).offsets );
                    if ~isempty(pointed_saccade_i)
                        pointed_saccade_i= pointed_saccade_i(1);
                        pointed_saccade_amp= obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).amplitudes(pointed_saccade_i);
                        pointed_saccade_peak_vel= obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).peak_vels(pointed_saccade_i);
                        primal_text_x_pos= curr_axes_point_x - obj.timeline_left_offset + 0.25*epsilon;
                        primal_text_y_pos= curr_axes_point_y+0.25*epsilon;
                        obj.curr_displayed_tooltip= text(primal_text_x_pos, primal_text_y_pos, ['amplitude= ', num2str(pointed_saccade_amp), ' ; ', 'peak velocity= ', num2str(pointed_saccade_peak_vel)], 'parent', curr_axes);

                        tooltip_extent= get(obj.curr_displayed_tooltip, 'extent');
                        tooltip_right_edge= tooltip_extent(1)+tooltip_extent(3);
                        eye_coords_axes_xlim= get(curr_axes, 'XLim');
                        if tooltip_right_edge>eye_coords_axes_xlim(2)
                            updated_text_x_pos= curr_axes_point_x - obj.timeline_left_offset + 0.25*epsilon - (tooltip_right_edge-eye_coords_axes_xlim(2));
                        else
                            updated_text_x_pos= primal_text_x_pos;
                        end
                        eye_coords_axes_ylim= get(curr_axes, 'YLim');
                        tooltip_top_edge= tooltip_extent(2)+tooltip_extent(4);
                        if tooltip_top_edge>eye_coords_axes_ylim(2)
                            updated_text_y_pos= curr_axes_point_y - 0.5*epsilon;
                        else
                            updated_text_y_pos= primal_text_y_pos;
                        end

                        set(obj.curr_displayed_tooltip, 'position', [updated_text_x_pos, updated_text_y_pos, 0]);
                    end                                
                end    
                
                if obj.is_blink_being_drawn_on_x_axes 
                    delete(obj.blink_curr_marker_h);
                    obj.blink_curr_marker_h = plot(obj.eyes_x_coords_axes, [curr_axes_point_x, curr_axes_point_x] - obj.timeline_left_offset, obj.mean_range + 4*obj.std_range*[-1,1], '-b');
                    set(obj.blink_curr_marker_h, 'ButtonDownFcn', @obj.eyeCoordsXAxesButtonDownCallback);
                elseif obj.is_blink_being_drawn_on_y_axes
                    delete(obj.blink_curr_marker_h);
                    obj.blink_curr_marker_h = plot(obj.eyes_y_coords_axes, [curr_axes_point_x, curr_axes_point_x] - obj.timeline_left_offset, obj.mean_range + 4*obj.std_range*[-1,1], '-b');
                    set(obj.blink_curr_marker_h, 'ButtonDownFcn', @obj.eyeCoordsYAxesButtonDownCallback);
                end
            end
            
            function res= isCursorCloseToPlot()
                res= ( curr_axes==obj.eyes_x_coords_axes && (abs(curr_subject_trial_eye_data_struct.left_x(curr_axes_point_x)-curr_axes_point_y)<=epsilon || abs(curr_subject_trial_eye_data_struct.right_x(curr_axes_point_x)-curr_axes_point_y)<=epsilon) ) || ...
                     ( curr_axes==obj.eyes_y_coords_axes && (abs(curr_subject_trial_eye_data_struct.left_y(curr_axes_point_x)-curr_axes_point_y)<=epsilon || abs(curr_subject_trial_eye_data_struct.right_y(curr_axes_point_x)-curr_axes_point_y)<=epsilon) );
            end
        end
        
        function keyPressCallback(obj, ~, eventdata)
            key_pressed= eventdata.Key;
            if ~isempty(eventdata.Modifier)
                modifier= eventdata.Modifier{1};
            else
                modifier= [];
            end
            if strcmpi(key_pressed, 'rightarrow')
                if isempty(modifier)
                    obj.displayedTrialAdvancePressedCallback();
                elseif strcmpi(modifier, 'control')
                    obj.currSubjectAdvancePressedCallback()
                end
            elseif strcmpi(key_pressed, 'leftarrow')
                if isempty(modifier)
                    obj.displayedTrialReversePressedCallback();
                elseif strcmpi(modifier, 'control')
                    obj.currSubjectReversePressedCallback()
                end
            elseif strcmpi(key_pressed, 'period')
                obj.centerViewOnLaterSaccadePressedCallback();
            elseif strcmpi(key_pressed, 'comma')
                obj.centerViewOnEarlyerSaccadePressedCallback();
            elseif strcmpi(key_pressed, 's')
                if isempty(modifier)
                    obj.selectPressedCallback();
                elseif strcmpi(modifier, 'control')
                    obj.savePressedCallback()
                end
            elseif strcmpi(key_pressed, 'p')
                obj.panPressedCallback();
                turnOffMatlabListeners();                    
            elseif strcmpi(key_pressed, 'y') && ~isempty(modifier) && strcmpi(modifier, 'control')
                obj.redoPressedCallback();
            elseif strcmpi(key_pressed, 'z')
                if isempty(modifier)
                    obj.zoomInPressedCallback();
                    turnOffMatlabListeners();
                elseif strcmpi(modifier, 'control')
                    obj.undoPressedCallback();                    
                elseif strcmpi(modifier, 'alt')
                    obj.zoomOutPressedCallback();
                    turnOffMatlabListeners();
                end
            end
                                           
            function turnOffMatlabListeners()
                hManager = uigetmodemanager(obj.fig);
                try
                    set(hManager.WindowListenerHandles, 'Enable', 'off');  % HG1
                catch
                    [hManager.WindowListenerHandles.Enabled] = deal(false);  % HG2
                end                  
                set(obj.fig, 'KeyPressFcn', @obj.keyPressCallback);
            end
        end
          
        function rejectRestoreTrial(obj, ~, ~)            
            obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).is_trial_accepted = ...
                ~obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).is_trial_accepted;                        
            if obj.eyeballing_altered_saccades_data{obj.curr_subject}(obj.curr_trial).is_trial_accepted               
                delete(obj.rejection_texts{obj.curr_subject}{obj.curr_trial});
            else
                obj.rejection_texts{obj.curr_subject}{obj.curr_trial} = [text(sum(get(obj.eyes_x_coords_axes, 'XLim'))/2, sum(get(obj.eyes_x_coords_axes, 'YLim'))/2, 'REJECTED', 'parent', obj.eyes_x_coords_axes, 'Color', [1, 0, 0], 'FontSize', 20), ...
                                                                         text(sum(get(obj.eyes_y_coords_axes, 'XLim'))/2, sum(get(obj.eyes_y_coords_axes, 'YLim'))/2, 'REJECTED', 'parent', obj.eyes_y_coords_axes, 'Color', [1, 0, 0], 'FontSize', 20)];            
            end
                
        end
            
        function displayMsg(obj, msg)
            
        end
    end        
    
    methods (Access= private, Static)
        function newExtractionParamEditedCallback(hObject, ~, inputVerifier)
            input= get(hObject,'string');                        
            if inputVerifier(input)
                set(hObject,'UserData', input);
            else                                
                set(hObject, 'string', get(hObject, 'UserData'));
            end              
        end
        
        function changeSaccadePlotsColors(saccade_plots_hs_vec, color)
            for saccade_plot_h_i= 1:numel(saccade_plots_hs_vec)-4
                set(saccade_plots_hs_vec(saccade_plot_h_i), 'color', color);
            end
            
            for saccade_edge_mark_plot_h_i= 0:7
                set(saccade_plots_hs_vec(end - saccade_edge_mark_plot_h_i), 'MarkerEdgeColor', color);               
            end
        end
        
        function clearSaccadePlots(saccade_plot_hs)               
            for saccade_plot_h= saccade_plot_hs  
                if ishandle(saccade_plot_h)
                    set(saccade_plot_h, 'visible', 'off');                
                end
            end                        
        end                              
        
        function res= isStrAValidPositiveInteger(str)
            res= ~isempty(str) && isempty(find(~isstrprop(str,'digit'),1)) && ~strcmp(str(1),'0');
        end
        
        function res= isStrAValidNonNegativeInteger(str)
            if ~isempty(str) && isempty(find(~isstrprop(str,'digit'),1))
                if numel(str)==1 || ~strcmp(str(1),'0')
                    res= true;
                else
                    res= false;
                end
            else
                res= false;
            end
        end

        function res= isStrAPositiveRealNumber(str)
            non_digit_chars_is= find(~isstrprop(str,'digit'));
            if numel(non_digit_chars_is)==0 || (numel(non_digit_chars_is)==1 && strcmp(str(non_digit_chars_is),'.') && non_digit_chars_is~=1 && non_digit_chars_is~=numel(str))
                res= true;
            else
                res= false;
            end
        end

        function res= isStrAValidNonNegativeReal(str)
            if isempty(str)
                res= false;
                return;
            end

            non_digit_chars_is= find(~isstrprop(str,'digit'));
            if Eyeballer.isStrAValidNonNegativeInteger(str) || ...
                    Eyeballer.strHasOnlyAValidDecimalPoint(str, non_digit_chars_is) && (non_digit_chars_is==2 || ~strcmp(str(1),'0'))
                res= true;
            else
                res= false;
            end
        end

        function res= strHasOnlyAValidDecimalPoint(str, non_digit_chars_is)
            res= numel(non_digit_chars_is)==1 && ...
                strcmp(str(non_digit_chars_is),'.') && ...
                non_digit_chars_is~=1 && ...
                non_digit_chars_is~=numel(str);
        end
    end
end

