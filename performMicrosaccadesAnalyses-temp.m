% //////////////////////////////////////////////////////////////////////////
% INPUT:
%   analysis_struct: cell array with a cell for each subject -> struct with
%   a field for each condition -> structure with field: onsets (matrix[n,t]:
%   n->number of trials, t->trial length), number of saccades (array[n]:
%   n-> number of trials),  amplitudes (under construction), directions
%   (current structure -> just a simple array of the saccades directions
% //////////////////////////////////////////////////////////////////////////
function [subjects_figs, statistisized_figs, analysis_struct_with_results]= performMicrosaccadesAnalyses(analysis_struct, exe_plot_curves, analyses, baseline, smoothing_window_len, trial_duration, progress_screen, progress_contribution)
    CURVES_COLORS= [1.0, 0.0, 0.0;  0.0, 1.0, 0.0;  0.0, 0.0, 1.0;  0.1, 0.1, 0.1;
        1.0, 1.0, 0.0;  1.0, 0.0, 1.0;  1, 0.7333, 0.0;  0.0, 1.0, 1.0;
        0.4, 0.8, 0.1;  0.4, 0.1, 0.8;  0.8, 0.4, 0.1;  0.8, 0.1, 0.4];   
    
    %SUBJECTS_INITIALS = {'ad', 'bl', 'ec', 'hl', 'jp', 'ma', 'rd', 'ty', 'vp', 'zw'}; 
    %SUBJECTS_INITIALS = {'bl', 'ca', 'ec', 'en', 'ew', 'jl', 'jx', 'ld', 'ml', 'rd', 'sj'}; 
    SUBJECTS_INITIALS = {'ds', 'gb', 'ht', 'ik', 'jg', 'jp', 'rd', 'xw', 'yz'}; 
    
    TIME_LINE_LEFT_SHIFT = 1000;
    DIRECTIONS_BINS_LIMS = [-999       -800;
                            -799       -600;
                            -599       -400;
                            -399       -200;
                            -199        0;
                            1           200;
                            201     	400;
                            401     	600;
                            601         800] + TIME_LINE_LEFT_SHIFT + baseline;    
        
    screen_size= get(0,'monitorpositions');    
    if any(screen_size(1,:)<0)
        screen_size= get(0,'ScreenSize');
    end    
    
    screen_size= screen_size(1,:);
    figure_positions= round([0.1*screen_size(3), 0.1*screen_size(4), 0.8*screen_size(3), 0.8*screen_size(4)]);
    conds_names= fieldnames(analysis_struct{1});
    conds_nr= numel(conds_names);
    if exe_plot_curves
        str_for_visible_prop= 'on';
    else
        str_for_visible_prop= 'off';
    end
    
    subjects_nr= numel(analysis_struct);
    subjects_figs= cell(2,2*sum(analyses),subjects_nr);
    analysis_struct_with_results.microsaccades_data= analysis_struct;
    analysis_struct_with_results.results_per_subject= cell(1, subjects_nr);
    analysis_struct_with_results.results_grand_total= [];
    
    % saccadic rate              
    max_trial_duration_per_cond = zeros(1, conds_nr);
    original_microsaccadic_rate = cell(1, conds_nr);
    smoothed_microsaccadic_rate = cell(1, conds_nr);
    for cond_i= 1:conds_nr
        for subject_i = 1:subjects_nr
            if max_trial_duration_per_cond(cond_i) < size(analysis_struct{subject_i}.(conds_names{cond_i}).logical_onsets_mat, 2);
                max_trial_duration_per_cond(cond_i) = size(analysis_struct{subject_i}.(conds_names{cond_i}).logical_onsets_mat, 2);
            end
        end
        original_microsaccadic_rate{cond_i} = zeros(subjects_nr, max_trial_duration_per_cond(cond_i));
        smoothed_microsaccadic_rate{cond_i} = zeros(subjects_nr, max_trial_duration_per_cond(cond_i) - smoothing_window_len);
    end
    
    for subject_i= 1:subjects_nr
        curr_created_plots_nr= 0;
        if isempty(analysis_struct{subject_i})
            progress_screen.addProgress(0.5*progress_contribution/subjects_nr);
            continue;
        end
        
        curr_created_plots_nr= curr_created_plots_nr + 1;
        %smooth window
        smoothing_edge_left= floor(smoothing_window_len/2);
        smoothing_edge_right= ceil(smoothing_window_len/2);
        for cond_i= 1:conds_nr
            max_trial_duration = max_trial_duration_per_cond(cond_i);
            original_microsaccadic_rate{cond_i}(subject_i, 1:size(analysis_struct{subject_i}.(conds_names{cond_i}).logical_onsets_mat, 2)) = 1000 * nanmean(analysis_struct{subject_i}.(conds_names{cond_i}).logical_onsets_mat, 1);
            smoothed_microsaccadic_rate_with_tails = smoothy( original_microsaccadic_rate{cond_i}(subject_i, 1:size(analysis_struct{subject_i}.(conds_names{cond_i}).logical_onsets_mat,2)), smoothing_window_len, progress_screen, 0.5*progress_contribution/(conds_nr*subjects_nr) );
            smoothed_microsaccadic_rate{cond_i}(subject_i, :) = smoothed_microsaccadic_rate_with_tails((smoothing_edge_left + 1):(max_trial_duration - smoothing_edge_right));
        end
        
        subjects_figs{1,curr_created_plots_nr,subject_i}= ['microsaccades_rate_', SUBJECTS_INITIALS{subject_i}];
        subjects_figs{2,curr_created_plots_nr,subject_i}= figure('name','microsaccades_rate','NumberTitle', 'off', 'position', figure_positions, 'visible', str_for_visible_prop);
        for cond_i= 1:conds_nr
            if strcmp(SUBJECTS_INITIALS{subject_i}, 'id')
                plot(((smoothing_edge_left + 1):2:(max_trial_duration_per_cond(cond_i) - smoothing_edge_right)) - baseline - TIME_LINE_LEFT_SHIFT, ...
                    1000*smoothed_microsaccadic_rate{cond_i}(subject_i,1:size(analysis_struct{subject_i}.(conds_names{cond_i}).logical_onsets_mat,2) - floor(smoothing_window_len/2)), 'color', CURVES_COLORS(cond_i,:));  
            else
                plot(((smoothing_edge_left + 1):(max_trial_duration_per_cond(cond_i) - smoothing_edge_right)) - baseline - TIME_LINE_LEFT_SHIFT, ...
                    1000*smoothed_microsaccadic_rate{cond_i}(subject_i,:), 'color', CURVES_COLORS(cond_i,:));                
            end
            analysis_struct_with_results.results_per_subject{subject_i}.microsaccadic_rate.(conds_names{cond_i})= smoothed_microsaccadic_rate{cond_i}(subject_i,:);
            hold('on');
        end
        
        legend({'Attend both', 'Attend T1', 'Attend T2', 'Attend T3'});
        %line([1000,1000], [0, 100], 'Color', [0, 0, 0]);
        %line([1250,1250], [0, 100], 'Color', [0, 0, 0]);        
        text(0, -0.5, 'T1');
        text(250, -0.5, 'T2');
        xlabel('Time [ms]');
        ylabel('Microsaccadic Rate [hz]');                
    end   
        
    % main sequence    
    for subject_i= 1:subjects_nr
        data_filled_conds_logical_vec= logical(true(numel(conds_names),1));
        curr_created_plots_nr= curr_created_plots_nr + 1;
        subjects_figs{1,curr_created_plots_nr,subject_i}= ['main_sequence_by_condition_',SUBJECTS_INITIALS{subject_i}];
        subjects_figs{2,curr_created_plots_nr,subject_i}= figure('name','main sequence by condition', 'NumberTitle', 'off', 'position', figure_positions, 'visible', str_for_visible_prop);
        for cond_i= 1:conds_nr
            amplitudes= [analysis_struct{subject_i}.(conds_names{cond_i}).amplitudes{:}];
            velocities= [analysis_struct{subject_i}.(conds_names{cond_i}).velocities{:}];
            if isempty(amplitudes) || isempty(velocities)
                data_filled_conds_logical_vec(cond_i)= false;
                continue;
            end
            plot_h= plot(amplitudes, velocities, '.', 'MarkerSize', 5);
            set(plot_h, 'color', CURVES_COLORS(cond_i,:));
            hold('on');
        end
        legend({'Attend both', 'Attend T1', 'Attend T2', 'Attend T3'});
        
        curr_created_plots_nr= curr_created_plots_nr + 1;
        subjects_figs{1,curr_created_plots_nr,subject_i}= ['main_sequence_',SUBJECTS_INITIALS{subject_i}];
        subjects_figs{2,curr_created_plots_nr,subject_i}= figure('name','main sequence', 'NumberTitle', 'off', 'position', figure_positions, 'visible', str_for_visible_prop);
        if any(data_filled_conds_logical_vec)
            velocities= [];
            amplitudes = [];
            for cond_i= 1:conds_nr
                velocities= [velocities, analysis_struct{subject_i}.(conds_names{cond_i}).velocities{:}]; %#ok<AGROW>
                amplitudes= [amplitudes, analysis_struct{subject_i}.(conds_names{cond_i}).amplitudes{:}]; %#ok<AGROW>
            end
            
            plot(amplitudes, velocities, '.k', 'MarkerSize', 5);
        end
        [pearson_r, pearson_p_value] = corr(velocities',amplitudes');
        set(gca, 'title', text(0,0,['Pearson''s r = ', num2str(pearson_r), ', p-value = ', num2str(pearson_p_value)]));
    end   
        
    % blinks    
    original_blinks_rate = cell(1, conds_nr);
    smoothed_blinks_rate = cell(1, conds_nr);
    for cond_i= 1:conds_nr        
        original_blinks_rate{cond_i} = zeros(subjects_nr, max_trial_duration_per_cond(cond_i));
        smoothed_blinks_rate{cond_i} = zeros(subjects_nr, max_trial_duration_per_cond(cond_i) - smoothing_window_len);
    end
    
    for subject_i= 1:subjects_nr      
        if isempty(analysis_struct{subject_i})
            progress_screen.addProgress(0.5*progress_contribution/subjects_nr);
            continue;
        end
          
        %smooth window
        smoothing_edge_left= floor(smoothing_window_len/2);
        smoothing_edge_right= ceil(smoothing_window_len/2);
        for cond_i= 1:conds_nr
            max_trial_duration = max_trial_duration_per_cond(cond_i);
            original_blinks_rate{cond_i}(subject_i, 1:size(analysis_struct{subject_i}.(conds_names{cond_i}).logical_onsets_mat,2)) = nanmean(~analysis_struct{subject_i}.(conds_names{cond_i}).non_nan_times, 1);
            smoothed_blinks_rate_with_tails = smoothy( original_blinks_rate{cond_i}(subject_i, 1:size(analysis_struct{subject_i}.(conds_names{cond_i}).logical_onsets_mat,2)), smoothing_window_len, progress_screen, 0.5*progress_contribution/(conds_nr*subjects_nr) );
            smoothed_blinks_rate{cond_i}(subject_i, :) = smoothed_blinks_rate_with_tails((smoothing_edge_left + 1):(max_trial_duration - smoothing_edge_right));
        end
        
        curr_created_plots_nr= curr_created_plots_nr + 1;
        subjects_figs{1,curr_created_plots_nr,subject_i}= ['blinks_rate_', SUBJECTS_INITIALS{subject_i}];
        subjects_figs{2,curr_created_plots_nr,subject_i}= figure('name','blinks_rate','NumberTitle', 'off', 'position', figure_positions, 'visible', str_for_visible_prop);
        for cond_i= 1:conds_nr
            if strcmp(SUBJECTS_INITIALS{subject_i}, 'id')
                plot(((smoothing_edge_left + 1):2:(max_trial_duration_per_cond(cond_i) - smoothing_edge_right)) - baseline - TIME_LINE_LEFT_SHIFT, ...
                    smoothed_blinks_rate{cond_i}(subject_i,1:size(analysis_struct{subject_i}.(conds_names{cond_i}).logical_onsets_mat,2) - floor(smoothing_window_len/2)), 'color', CURVES_COLORS(cond_i,:));    
            else
                plot(((smoothing_edge_left + 1):(max_trial_duration_per_cond(cond_i) - smoothing_edge_right)) - baseline - TIME_LINE_LEFT_SHIFT, ...
                    smoothed_blinks_rate{cond_i}(subject_i,:), 'color', CURVES_COLORS(cond_i,:));                
            end
            analysis_struct_with_results.results_per_subject{subject_i}.blinks_rate.(conds_names{cond_i})= smoothed_blinks_rate{cond_i}(subject_i,:);
            hold('on');
        end
        
        legend({'Attend both', 'Attend T1', 'Attend T2', 'Attend T3'});
        %line([1000,1000], [0, 100], 'Color', [0, 0, 0]);
        %line([1250,1250], [0, 100], 'Color', [0, 0, 0]);        
        %text(1000, -0.5, 'T1');
        %text(1250, -0.5, 'T2');
        xlabel('Time [ms]');
        ylabel('Blinks Rate [hz]');                
    end    
          
    %CREATE GRAND AVERAGE PLOTS
    curr_created_plots_nr= 0;        
    
    % micro-saccadic rate    
    curr_created_plots_nr= curr_created_plots_nr + 1;
    smoothed_grand_microsaccadic_rate= zeros(conds_nr, max_trial_duration_per_cond(cond_i) - smoothing_window_len);
    for cond_i= 1:conds_nr
        curr_cond_original_grand_microsaccadic_rate= nanmean(original_microsaccadic_rate{cond_i}, 1);        
        smoothed_grand_microsaccadic_rate_with_tails= smoothy( curr_cond_original_grand_microsaccadic_rate, smoothing_window_len, progress_screen, 0 );
        smoothed_grand_microsaccadic_rate(cond_i,:)= smoothed_grand_microsaccadic_rate_with_tails((smoothing_edge_left + 1):(max_trial_duration_per_cond(cond_i) - smoothing_edge_right));
    end
    
    statistisized_figs{1,curr_created_plots_nr}= 'grand_average-microsaccades_rate';
    statistisized_figs{2,curr_created_plots_nr}= figure('name','grand average: microsaccades rate', 'NumberTitle', 'off', 'position', figure_positions, 'visible', str_for_visible_prop);
    for cond_i= 1:conds_nr
        plot(((smoothing_edge_left + 1):(max_trial_duration_per_cond(cond_i) - smoothing_edge_right)) - baseline - TIME_LINE_LEFT_SHIFT, smoothed_grand_microsaccadic_rate(cond_i,:), 'color', CURVES_COLORS(cond_i,:));
        analysis_struct_with_results.results_grand_total.microsaccadic_rate.(conds_names{cond_i})= smoothed_grand_microsaccadic_rate(cond_i,:);
        hold('on');
    end
    legend({'Attend both', 'Attend T1', 'Attend T2', 'Attend T3'});
    %line([1000,1000], [0, 100], 'Color', [0, 0, 0]);
    %line([1250,1250], [0, 100], 'Color', [0, 0, 0]);       
    xlabel('Time [ms]');
    ylabel('Microsaccadic Rate [hz]');
           
    % main sequence
    data_filled_conds_logical_vec= logical(true(numel(conds_names),1));    
    curr_created_plots_nr= curr_created_plots_nr + 1;
    grand_velocities= cell(1,conds_nr);
    grand_amplitudes = cell(1,conds_nr);
    for cond_i=1:conds_nr
        grand_velocities{cond_i}= [];
        grand_amplitudes{cond_i} = [];
        for subject_i= 1:subjects_nr
            grand_velocities{cond_i}= [grand_velocities{cond_i}, analysis_struct{subject_i}.(conds_names{cond_i}).velocities{:}];
            grand_amplitudes{cond_i}= [grand_amplitudes{cond_i}, analysis_struct{subject_i}.(conds_names{cond_i}).amplitudes{:}];
        end
    end
    
    statistisized_figs{1,curr_created_plots_nr}= 'grand_average-main_sequence_by_condition';
    statistisized_figs{2,curr_created_plots_nr}= figure('name','grand average: main sequence by condition', 'NumberTitle', 'off', 'position', figure_positions, 'visible', str_for_visible_prop);
    for cond_i= 1:conds_nr
        if isempty(grand_velocities{cond_i}) || isempty(grand_amplitudes{cond_i})
            data_filled_conds_logical_vec(cond_i)= false;
            continue;
        end
        plot_h= plot(grand_amplitudes{cond_i}, grand_velocities{cond_i}, '.', 'MarkerSize', 5);
        set(plot_h, 'color', CURVES_COLORS(cond_i,:));
        hold('on');
    end
    legend({'Attend both', 'Attend T1', 'Attend T2', 'Attend T3'});
    
    curr_created_plots_nr= curr_created_plots_nr + 1;    
    statistisized_figs{1,curr_created_plots_nr}= 'grand_average-main_sequence';
    statistisized_figs{2,curr_created_plots_nr}= figure('name','grand average: main sequence ', 'NumberTitle', 'off', 'position', figure_positions, 'visible', str_for_visible_prop);
    if any(data_filled_conds_logical_vec)
        grand_velocities_over_conditions= [];
        grand_amplitudes_over_conditions= [];
        for cond_i=1:conds_nr
            grand_velocities_over_conditions= [grand_velocities_over_conditions, grand_velocities{cond_i}];	%#ok<AGROW>
            grand_amplitudes_over_conditions= [grand_amplitudes_over_conditions, grand_amplitudes{cond_i}];	%#ok<AGROW>
        end
        plot(grand_amplitudes_over_conditions, grand_velocities_over_conditions, '.k', 'MarkerSize', 5);
    end
    [pearson_r, pearson_p_value] = corr(grand_velocities_over_conditions',grand_amplitudes_over_conditions');
    set(gca, 'title', text(0,0,['Pearson''s r = ', num2str(pearson_r), ', p-value = ', num2str(pearson_p_value)]));    
    
    % blinks rate        
    smoothed_grand_blinks_rate= zeros(conds_nr, max_trial_duration_per_cond(cond_i) - smoothing_window_len);
    for cond_i= 1:conds_nr
        curr_cond_original_grand_blinks_rate= nanmean(original_blinks_rate{cond_i}, 1);
        smoothed_grand_blinks_rate_with_tails= smoothy( curr_cond_original_grand_blinks_rate, smoothing_window_len, progress_screen, 0 );
        smoothed_grand_blinks_rate(cond_i,:)= smoothed_grand_blinks_rate_with_tails((smoothing_edge_left + 1):(max_trial_duration_per_cond(cond_i) - smoothing_edge_right));
    end
    
    curr_created_plots_nr= curr_created_plots_nr + 1;
    statistisized_figs{1,curr_created_plots_nr}= 'grand_average-blinks_rate';
    statistisized_figs{2,curr_created_plots_nr}= figure('name','grand average: blinks rate', 'NumberTitle', 'off', 'position', figure_positions, 'visible', str_for_visible_prop);
    for cond_i= 1:conds_nr
        plot(((smoothing_edge_left + 1):(max_trial_duration_per_cond(cond_i) - smoothing_edge_right)) - baseline - TIME_LINE_LEFT_SHIFT, smoothed_grand_blinks_rate(cond_i,:), 'color', CURVES_COLORS(cond_i,:));
        analysis_struct_with_results.results_grand_total.blinks_rate.(conds_names{cond_i})= smoothed_grand_blinks_rate(cond_i,:);
        hold('on');
    end
    legend({'Attend both', 'Attend T1', 'Attend T2', 'Attend T3'});
    %line([1000,1000], [0, 100], 'Color', [0, 0, 0]);
    %line([1250,1250], [0, 100], 'Color', [0, 0, 0]);       
    xlabel('Time [ms]');
    ylabel('Blinks Rate [hz]');
    
    % directions    
    bins_nr = size(DIRECTIONS_BINS_LIMS, 1);
    directions = cell(bins_nr, conds_nr, subjects_nr);
    directions_acc_accross_subjects = cell(bins_nr, conds_nr);
    for bin_i = 1:bins_nr        
        for cond_i= 1:conds_nr                        
            directions_acc_accross_subjects{bin_i, cond_i} = [];
            for subject_i= 1:subjects_nr                
                onsets = [analysis_struct{subject_i}.(conds_names{cond_i}).onsets{:}]; 
                curr_subject_directions = [analysis_struct{subject_i}.(conds_names{cond_i}).directions{:}];
                directions{bin_i, cond_i, subject_i} = curr_subject_directions(DIRECTIONS_BINS_LIMS(bin_i, 1) <= onsets & onsets <= DIRECTIONS_BINS_LIMS(bin_i, 2));
                directions_acc_accross_subjects{bin_i, cond_i} = [directions_acc_accross_subjects{bin_i, cond_i}, directions{bin_i, cond_i, subject_i}];                    
            end            
            analysis_struct_with_results.results_per_subject{subject_i}.directions{bin_i}.(conds_names{cond_i}) = directions{bin_i, cond_i, subject_i};
        end        
    end                     
    analysis_struct_with_results.results_grand_total.directions = directions;
    
%     for bin_i = 1:bins_nr
%         curr_created_plots_nr= curr_created_plots_nr + 1;
%         statistisized_figs{1,curr_created_plots_nr}= ['directions_between_', num2str(DIRECTIONS_BINS_LIMS(bin_i, 1)-TIME_LINE_LEFT_SHIFT - baseline), '_and_', num2str(DIRECTIONS_BINS_LIMS(bin_i, 2)-TIME_LINE_LEFT_SHIFT- baseline)];
%         statistisized_figs{2,curr_created_plots_nr}= figure('name',['directions betweeen ', num2str(DIRECTIONS_BINS_LIMS(bin_i, 1)-TIME_LINE_LEFT_SHIFT- baseline), ' and ', num2str(DIRECTIONS_BINS_LIMS(bin_i, 2)-TIME_LINE_LEFT_SHIFT- baseline)], 'NumberTitle', 'off', 'position', figure_positions, 'visible', str_for_visible_prop);
%         polar(360,1000);
%         for cond_i= conds_nr:-1:1        
%             rose_h= rose(directions_acc_accross_subjects{bin_i, cond_i});
%             set(rose_h, 'color', CURVES_COLORS(cond_i,:));
%             hold('on');
%         end 
%         polar(360,1000);
%         legend({'Attend T3', 'Attend T2', 'Attend T1', 'Attend Both'});
%     end
end