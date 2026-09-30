function report=test_smoke_resume(destination)
%TEST_SMOKE_RESUME Fresh, bounded experiment + checkpoint reuse integration.
% Run from the package root with: addpath('tests');test_smoke_resume
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);prpaper_setup();
if nargin<1,destination=fullfile(root,'runs',['test_smoke_' datestr(now,'yyyymmdd_HHMMSS_FFF')]);end
assert(~isfolder(destination),'Use a new destination.');
f=RUN_SMOKE(destination,1);a=load(f,'state');
assert(~a.state.complete&&strcmp(a.state.stages.base.status,'partial'));
b=load(fullfile(destination,'raw','base','checkpoint.mat'),'output');
entry=b.output.conditions{1}.batches{1};p=fullfile(destination,'raw','base',entry.file);before=dir(p);
f=RUN_RESUME(destination);a=load(f,'output');
assert(a.output.complete&&~a.output.paper_ready&&numel(a.output.figures)==18);
after=dir(p);assert(before.bytes==after.bytes&&before.datenum==after.datenum);
assert(strcmp(which('RUN_SMOKE'),fullfile(root,'RUN_SMOKE.m')),'Public entry point is shadowed');
bad=prpaper_config('smoke');bad.destination=destination;bad.base.master_seed=bad.base.master_seed+1;caught=false;
try,prpaper_run('paper',bad);catch ME,caught=strcmp(ME.identifier,'PRPAPER:ResumeMismatch');end
assert(caught,'Changed numerical settings reused a checkpoint');
report=struct('passed',true,'budget_pause',true,'checkpoint_reused',true,...
 'source_identity_guard',true,'launcher_path_restored',true,'figure_count',18,...
 'full_smoke_pipeline',true,'paper_ready',false,'matlab',version);
save(fullfile(destination,'smoke_test_report.mat'),'report','-v7');
fid=fopen(fullfile(destination,'smoke_test_report.json'),'w');clean=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
end
