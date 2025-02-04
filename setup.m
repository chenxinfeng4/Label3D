function setuplilab()
    pf = mfilename('fullpath');
    p  = fileparts(pf);
    addpath(p);
    addpath(genpath(fullfile(p,'deps')));
    savepath()
    disp('setup successfully!');
end