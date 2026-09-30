function outputFile=run_jog_v2(profile,outputDir,varargin)
%RUN_JOG_V2 Complete standalone legacy + revision experiment package.
% run_jog_v2('smoke'); cfg=jog_config_v2('paper'); run_jog_v2(cfg,folder);
% run_jog_v2('resume',folder) resumes exact config/source from checkpoints.
if nargin<1,profile='smoke';end
root=fileparts(mfilename('fullpath'));addpath(root);
p=inputParser;addParameter(p,'MaxBatches',Inf);parse(p,varargin{:});
resuming=(ischar(profile)||isstring(profile))&&strcmp(profile,'resume');
if resuming
 if nargin<2,error('Pass run folder');end
 o=jog2.Store.metadata(fullfile(outputDir,'checkpoint.mat'));cfg=o.config;
 assert(strcmp(o.meta.source_hash,jog2.Util.hash(jsonencode(jog2.Util.sources()))),'Source changed: start a separate run');
else
 if isstruct(profile),cfg=profile;else,cfg=jog_config_v2(char(profile));end
 jog2.Validate.config(cfg);
 if nargin<2||isempty(outputDir),outputDir=fullfile(pwd,'results',[cfg.profile '_' datestr(now,'yyyymmdd_HHMMSS_FFF')]);end
 o=jog2.Store.create(cfg,outputDir);o.validation.selftest=jog_selftest_v2(cfg);
 o.validation.preflight=jog2.Validate.preflight(cfg,outputDir);
 jog2.Store.checkpoint(o,outputDir);
end
limit=min(cfg.max_batches_per_session,p.Results.MaxBatches);done=0;t=tic;
try
 for si=1:numel(cfg.enabled)
  id=cfg.enabled{si};if any(strcmp(id,{'J15','J16'})),continue;end
  if ismember(id,o.progress.completed_suites),continue;end
  j=str2double(id(2:end));fprintf('\n%s / %s\n',id,cfg.profile);
  if j<9
   if j<7,x=jog.linear_suite(id,cfg);else,x=jog.plane_suite(id,cfg);end
   prefix=[o.meta.run_id '_' id];[e,~]=jog2.Store.write(outputDir,prefix,x);
   o.legacy.(id)=e;o.progress.completed_suites{end+1}=id;jog2.Store.checkpoint(o,outputDir);continue;
  end
  cases=jog2.Plan.make(id,cfg);
  for ci=1:numel(cases)
   idx=find(cellfun(@(c)strcmp(c.suite,id)&&c.spec.condition_id==ci,o.conditions),1);
   if isempty(idx)
    d=jog2.Plan.prepare(cases{ci},cfg);prefix=sprintf('%s_%sc%03d',o.meta.run_id,id,ci);
    [entry,~]=jog2.Store.write(outputDir,[prefix '_design'],d);
    c=struct('suite',id,'spec',d.spec,'prefix',prefix,'design',entry,'batches',{{}},...
     'completed_trial_ids',[],'run_id',o.meta.run_id);
    o.conditions{end+1}=c;idx=numel(o.conditions);jog2.Store.checkpoint(o,outputDir);
   else,c=o.conditions{idx};d=jog2.Store.design(fullfile(outputDir,'checkpoint.mat'),c);end
   remaining=setdiff(1:c.spec.N,c.completed_trial_ids);
   for first=1:cfg.batch_size:numel(remaining)
    ids=remaining(first:min(first+cfg.batch_size-1,numel(remaining)));
    b=jog2.Batch.run(d,cfg,ids);bn=numel(c.batches)+1;
    [e,~]=jog2.Store.write(outputDir,sprintf('%s_b%04d',c.prefix,bn),b,'batch');
    e.trial_ids=ids;c.batches{end+1}=e;c.completed_trial_ids=[c.completed_trial_ids ids];
    o.conditions{idx}=c;o.meta.last_session_seconds=toc(t);jog2.Store.checkpoint(o,outputDir);
    done=done+1;fprintf('  condition %d/%d, maps %d/%d\n',ci,numel(cases),numel(c.completed_trial_ids),c.spec.N);
    if done>=limit
     o.meta.status='partial';jog2.Store.checkpoint(o,outputDir);
     outputFile=fullfile(outputDir,'checkpoint.mat');fprintf('Partial checkpoint: %s\n',outputFile);return;
    end
   end
  end
  o.progress.completed_suites{end+1}=id;jog2.Store.checkpoint(o,outputDir);
 end
 outputFile=jog_finalize_v2(outputDir,'SourceRuns',cfg.source_runs);
 if cfg.analyze,jog_analyze_v2(outputFile,{'D01','D02','D03','D04','J15'});end
 if cfg.j16.enabled&&ismember('J16',cfg.enabled),jog_advanced_v2(outputFile,cfg.j16);end
 if cfg.make_figures,jog_make_figures_v2(outputFile,'paper');end
 jog_check_output_v2(outputFile,'strict');
 fprintf('\nComplete: %s\n',outputFile);
catch ME
 o.meta.status='failed';o.meta.last_error=struct('identifier',ME.identifier,'message',ME.message,'stack',ME.stack);
 jog2.Store.checkpoint(o,outputDir);rethrow(ME);
end
end
