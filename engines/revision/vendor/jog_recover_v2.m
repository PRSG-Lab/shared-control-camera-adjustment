function file=jog_recover_v2(source,destination,varargin)
% Recover completed raw simulations from v2.0 or v2.1 checkpoints.
% NEVER modifies source files and NEVER invokes a camera solver.
p=inputParser;addParameter(p,'Analyze',true);addParameter(p,'MakeFigures',true);
addParameter(p,'SourceRuns',[]);addParameter(p,'CheckIntegrity',true);addParameter(p,'MaxPackEntries',Inf);parse(p,varargin{:});
if isfolder(source),checkpoint=fullfile(source,'checkpoint.mat');
elseif endsWith(source,'checkpoint.mat'),checkpoint=source;
else,checkpoint=fullfile(fileparts(source),'checkpoint.mat');end
assert(exist(checkpoint,'file')==2,'checkpoint.mat and checkpoints/ are required. Select the original run folder.');
if nargin<2||isempty(destination)
 destination=fullfile(pwd,'results',['recovered_' datestr(now,'yyyymmdd_HHMMSS')]);
end
original=jog2.Store.metadata(checkpoint);jog2.Store.assertRawComplete(original);
fprintf('Recover raw run %s | %d conditions | no simulation will run\n',original.meta.run_id,numel(original.conditions));
% Old source-run merging requires separate conversion; never silently omit it.
sources=original.config.source_runs;
if ~isempty(p.Results.SourceRuns)
 assert(iscell(p.Results.SourceRuns)&&numel(p.Results.SourceRuns)==numel(sources),'Provide one converted archive for every original source run');
 sources=p.Results.SourceRuns;
end
for k=1:numel(sources),assert(jog2.Archive.isArchive(sources{k}),'Convert each old source run separately before merged recovery');end
file=jog2.Store.packCheckpoint(checkpoint,destination,sources,p.Results.MaxPackEntries);
if endsWith(file,'output.packing.mat'),return;end
if p.Results.Analyze,jog_analyze_v2(file);end
if p.Results.MakeFigures
 o=jog2.Store.metadata(file);assert(isfield(o.meta,'analysis_complete')&&o.meta.analysis_complete,'Complete analysis before rendering');
 jog_make_figures_v2(file,'paper');
end
if p.Results.CheckIntegrity,jog_check_output_v2(file);end
fprintf('Recovered: %s\n',file);
end
