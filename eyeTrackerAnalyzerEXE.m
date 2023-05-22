function eyeTrackerAnalyzerEXE()    
%     if ~exist('.git','file')
%         %1> nul 2> nul &
%         !git init
%         !git remote add origin https://github.com/shlomitya/eye-tracker-analyzer &   
%         !taskkill /F /im "cmd.exe" 1> nul 2> nul &
%     end
    
    !break > git_response.txt &
    !git fetch --dry-run 1> nul 2> git_response.txt &    
    !taskkill /F /im "cmd.exe" 1> nul 2> nul &
    pause(2.0);
    fid = fopen('git_response.txt');        
    git_fetch_dry_run_res = fgets(fid);
    fclose(fid);    
    if ischar(git_fetch_dry_run_res)    
        user_response = questdlg('A new version is available. Would you like to update?', 'Update Available', 'Update', 'Skip', 'Cancel', 'Update');
        if strcmp(user_response, 'Update')                    
            !git reset --hard origin/master &
            !git pull origin master &            
            !taskkill /F /im "cmd.exe" 1> nul 2> nul & 
        elseif strcmp(user_response, 'Cancel')
            return;        
        end      
    end    
    
    eyeTrackerAnalyzer();
end

