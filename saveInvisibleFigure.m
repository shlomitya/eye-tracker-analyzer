function saveInvisibleFigure(fig, filename)
    onCreateFunction= ['is_timer_done= false; t= timer(''TimerFcn'', ''set(gcf,''''Visible'''',''''on''''); is_timer_done= true;'', ''StartDelay'', 0.2);', ...
                      'start(t);']; 
           
    set(fig,'CreateFcn',onCreateFunction);
    savefig(fig,filename);
end


%  savefig(fig,filename);
%     f=load([filename,'.fig'],'-mat');
%     n=fieldnames(f);
%     f.(n{1}).properties.Visible='on';
%     save(filename,'-struct','f');