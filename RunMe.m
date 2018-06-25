function RunMe()
    cd('PortableGit');
    if ~exist('../.git','file')
        !git-cmd.exe git init 1> nul 2> nul
        !git remote add origin https://github.com/coriumgit/eye-tracker-analyzer
        !taskkill /F /im "cmd.exe" 1> nul 2> nul
    end
    
    !break > git_response.txt
    !git-cmd.exe git fetch --dry-run 1> nul 2> git_response.txt &    
    !taskkill /F /im "cmd.exe" 1> nul 2> nul
    pause(2.0);
    fid = fopen('git_response.txt');        
    git_fetch_dry_run_res = fgets(fid);
    fclose(fid);    
    if ischar(git_fetch_dry_run_res)    
        user_response = questdlg('A new version is available. Would you like to update?', 'Update Available', 'Update', 'Skip', 'Cancel', 'Update');
        if strcmp(user_response, 'Update')        
            % 1> nul 2> nul &
            !git-cmd.exe git pull origin master &
            !taskkill /F /im "cmd.exe" 1> nul 2> nul            
        elseif strcmp(user_response, 'Cancel')
            return;        
        end      
    end
    cd('..');
    
    eyeTrackerAnalyzer();
end

