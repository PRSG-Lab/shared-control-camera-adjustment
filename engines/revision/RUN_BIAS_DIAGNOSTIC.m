% Run this file from the downloaded package folder.
root=pr_setup();
source=prrev.IO.source(''); % original output.mat; file picker if default absent
opt=pr_config('paper');
destination=fullfile(root,'results','bias_paper');
% Set opt.max_tasks=1 to deliberately stop after one new checkpoint task.
resultFile=pr_run_bias(source,destination,opt);
fprintf('Result or checkpoint: %s\n',resultFile);
