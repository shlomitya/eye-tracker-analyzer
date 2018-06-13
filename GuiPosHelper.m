controls_is= [4.0, 4.1];
for control_i= controls_is
    curr_control_pos= get(findobj('tag',['c',num2str(control_i)]),'position');
    disp(['control #',num2str(control_i), ' position: ', num2str(curr_control_pos)]);
end
