% === myBarPlot ===
% plot grouped bars with standard deviation error bars
% data_mats:
% 1. if a matrix -> every column 
% TODO: fill this shit
function myBarPlot(data_mats, axes_title, y_axis_label, bars_labels, legend_labels)
    if iscell(data_mats)
        averaged_data_vecs= cellfun(@mean, data_mats, 'uniformoutput', false);
        data_mat= [];
        errors_mat= [];
        for group_i= 1:numel(data_mats)
            data_mat= [data_mat, averaged_data_vecs{group_i}'];
            errors_mat= [errors_mat, std(data_mats{group_i})/sqrt(numel(data_mats{group_i}))'];
        end
    else
        data_mat= mean(data_mats)';
        errors_mat= std(data_mats)';
    end

    bar_plots= bar(data_mat);
    ylabel(y_axis_label);
    set(gca, 'xtickl', bars_labels);
    if nargin==5
        legend(legend_labels{:});
    end

    groups_nr= numel(bar_plots);
    if groups_nr>1
        for bar_group_i= 1:numel(bar_plots)
            bars_x_pos_by_children = get(get(bar_plots(bar_group_i),'children'), 'XData');
            bars_x_pos= mean(bars_x_pos_by_children([1,3],:));
            hold on;
            curr_bars_data_vec= data_mat(:, bar_group_i);
            curr_bars_error_vec= errors_mat(:, bar_group_i);
            errorbar(bars_x_pos, curr_bars_data_vec, curr_bars_error_vec, '.k');
        end
    else
        bars_x_pos = get(bar_plots, 'XData');
        hold on;
        errorbar(bars_x_pos, data_mat, errors_mat, '.k');
    end

    if ~isempty(axes_title)
        title(axes_title);
    end
end