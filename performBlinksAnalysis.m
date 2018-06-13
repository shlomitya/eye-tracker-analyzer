function subjects_figs = performBlinksAnalysis( subjects_eye_data_structs,  window_size, progress_screen, progress_contribution)
    CURVES_COLORS= [1.0, 0.0, 0.0;  0.0, 1.0, 0.0;  0.0, 0.0, 1.0;  0.1, 0.1, 0.1;
        1.0, 1.0, 0.0;  1.0, 0.0, 1.0;  1, 0.7333, 0.0;  0.0, 1.0, 1.0;
        0.4, 0.8, 0.1;  0.4, 0.1, 0.8;  0.8, 0.4, 0.1;  0.8, 0.1, 0.4];
    curr_created_plots_nr= 0;
    conds_names= fieldnames(subjects_eye_data_structs{1});    
    trace_blinks= zeros(subjects_nr,trial_duration-WINDOW_SIZE, subjects_nr);
    
    curr_created_plots_nr= curr_created_plots_nr + 1;
    subjects_figs{1,curr_created_plots_nr,subject_i}= ['blinks_',num2str(subject_i)];
    subjects_figs{2,curr_created_plots_nr,subject_i}= figure('name','blinks', 'NumberTitle', 'off', 'position', figure_positions, 'visible', str_for_visible_prop);    
    progress_screen.displayMessage(['smoothing blinks for subject #', num2str(subject_i)]);
    for cond_i= 1:conds_nr
        orig_blinks= mean(subjects_eye_data_structs.blinks.(conds_names{cond_i}), 1); %<<<<==== update blinks struct name
        trace_blinks(subject_i,1:trial_duration,cond_i)= smoothy( orig_blinks, window_size, progress_screen, progress_contribution/conds_nr );
    end
    
    for cond_i= 1:conds_nr
        hold('on');
        plot(time_axis, trace_blinks(subject_i,:,cond_i)', 'color', CURVES_COLORS(cond_i,:));
    end

end

