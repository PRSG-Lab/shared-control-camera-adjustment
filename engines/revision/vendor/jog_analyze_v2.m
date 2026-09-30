function outputFile=jog_analyze_v2(input,diagnostics,varargin)
% Resumable condition analysis. Never restarts camera fitting.
if nargin<2,diagnostics={'D01','D02','D03','D04','J15'};end
p=inputParser;addParameter(p,'MaxConditions',Inf);parse(p,varargin{:});
if isstruct(input),input=input.output_file;end
if isfolder(input),input=fullfile(input,'output.mat');end
outputFile=input;o=jog2.Store.metadata(input);
assert(jog2.Archive.isArchive(input),'Run jog_recover_v2 on the old checkpoint folder first');
assert(o.meta.complete,'Raw archive is incomplete');
cfg=o.config;started=tic;done=0;
folder=fullfile(fileparts(input),'analysis_checkpoints');if ~exist(folder,'dir'),mkdir(folder);end
sourceHash=jog2.Util.hash(jsonencode(jog2.Util.sources()));
token=jog2.Util.hash([o.meta.pack_identity sourceHash jsonencode(diagnostics)]);
o.meta.analysis_complete=false;o.meta.status='analyzing';jog2.Store.saveMetadata(input,o);
o.summaries=cell(size(o.conditions));
for i=1:numel(o.conditions)
 c=o.conditions{i};cache=fullfile(folder,[c.prefix '_summary.mat']);
 if exist(cache,'file')
  previous=load(cache,'record');rr=previous.record;
  if strcmp(rr.token,token)&&strcmp(rr.prefix,c.prefix)
   o.summaries{i}=rr.summary;o.conditions{i}=rr.condition;
   fprintf('Analyze %s %d/%d | cached complete\n',c.suite,i,numel(o.conditions));continue;
  end
 end
 fprintf('Analyze %s %d/%d | statistics\n',c.suite,i,numel(o.conditions));one=tic;
 s=jog2.Analysis.condition(input,c,cfg);
 if ismember('J15',diagnostics)&&ismember('J15',cfg.enabled)&&ismember(c.suite,cfg.j15.source_suites)
  d=jog2.Store.design(input,c);targets=cell(size(c.batches));target_entries=cell(size(c.batches));
  for j=1:numel(c.batches)
   prefix=[c.batches{j}.prefix '_target'];probe=struct('prefix',prefix);
   if jog2.Archive.ready(input,probe,token)
    e=jog2.Archive.entry(input,prefix,'batch');t=jog2.Store.read(input,e);
   else
    b=jog2.Store.read(input,c.batches{j});t=jog2.Target.batch(b,d,cfg);
    e=jog2.Archive.putValue(input,prefix,t,'batch',token);
   end
   targets{j}=t;target_entries{j}=e;
   if mod(j,10)==0||j==numel(c.batches),fprintf('  J15 batch %d/%d | %.1f s\n',j,numel(c.batches),toc(one));end
  end
  c.target_batches=target_entries;s.targets=jog2.Target.summarize(targets,d,cfg);clear targets;
 end
 o.conditions{i}=c;o.summaries{i}=s;
 record=struct('token',token,'prefix',c.prefix,'summary',s,'condition',c,'completed_utc',jog2.Util.utc(),'seconds',toc(one));
 jog2.Util.saveAtomic(cache,'record',record);done=done+1;
 fprintf('Analyze %s %d/%d | saved complete, %.1f s\n',c.suite,i,numel(o.conditions),toc(one));
 if done>=p.Results.MaxConditions,fprintf('Analysis paused after completed condition; call jog_analyze_v2 again to resume.\n');return;end
end
o.diagnostics.geometry_population=jog2.Analysis.population(o);
if isfield(o.legacy,'J04')
 x=jog2.Store.read(input,o.legacy.J04);vf=cell(size(x.conditions));
 for ci=1:numel(x.conditions)
  cc=x.conditions{ci};values=cc.residual_energy/2;
  rejected=cc.residual_energy<jog.Core.chi2(.025,2)|cc.residual_energy>jog.Core.chi2(.975,2);
  vf{ci}=struct('tau',cc.tau,'values',values,'df',2,'mean',mean(values),...
   'rejection_rate',mean(rejected),'wilson',jog.Core.wilson(sum(rejected),numel(values)),...
   'reference','exact linear Gaussian, sigma0_squared=1');
 end
 o.diagnostics.J04_variance_factor=vf;
end
slopes={};sel=find(cellfun(@(c)strcmp(c.suite,'J10'),o.conditions));
if ~isempty(sel)
 gids=unique(cellfun(@(c)c.spec.geometry_id,o.conditions(sel)));
 for gid=gids
  ix=sel(cellfun(@(c)c.spec.geometry_id==gid&&ismember(c.spec.noise_scale,[.03 .1 .3]),o.conditions(sel)));
  if numel(ix)<3,continue;end
  xs=[];ys=[];invalid=[];
  for ci=ix
   mm=find(strcmp(o.summaries{ci}.methods,'GH_FULL'),1);if isempty(mm),continue;end
   a=o.summaries{ci}.method{mm};xs(end+1)=o.summaries{ci}.spec.noise_scale;
   ys(end+1)=a.remainder.normalized_rms;invalid(end+1)=a.n_total-a.n_valid;
  end
  ok=isfinite(ys)&ys>0;
  if nnz(ok)>=3,coef=polyfit(log(xs(ok)),log(ys(ok)),1);else,coef=[NaN NaN];end
  slopes{end+1}=struct('geometry_id',gid,'epsilon',xs,'rho',ys,'fit',coef,...
   'invalid_counts',invalid,'interpretation','diagnostic conditional slope; not an acceptance threshold');
 end
end
o.diagnostics.J10_small_noise_slopes=slopes;

o.diagnostics.completed=diagnostics;o.diagnostics.created_utc=jog2.Util.utc();
o.diagnostics.definition='D01 valid-fit bias/NEES/branches; D02 absolute-scale diagnostic; D03 metric-declared blocks; D04 true design';
o.meta.analysis_source_code=jog2.Util.sources();o.meta.analysis_source_hash=jog2.Util.hash(jsonencode(o.meta.analysis_source_code));
o.meta.analysis_complete=true;o.meta.status='analysis_complete';
o.meta.analysis_token=token;o.meta.analysis_seconds=toc(started);
jog2.Store.saveMetadata(input,o);
jog2.Export.tables(input);
end
