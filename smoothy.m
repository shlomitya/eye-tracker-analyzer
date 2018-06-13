function out = smoothy(signal, winlen, progress_screen, progress_contribution)    
    trace_length= length(signal) - winlen;
    c= zeros(1, trace_length);
    windStart=1;
    interval_progress_contribution= progress_contribution/floor(trace_length/floor(trace_length*0.1));
    for iPoint=1:trace_length
        windInds=windStart:windStart+winlen-1;
        c(iPoint)=mean(signal(windInds));    
        windStart= windStart+1;
        if mod(iPoint,floor(0.1*trace_length))==0
            progress_screen.addProgress(interval_progress_contribution);
        end
    end

    out=[zeros(1,floor(winlen/2)), c ,zeros(1,ceil(winlen/2))];
end
