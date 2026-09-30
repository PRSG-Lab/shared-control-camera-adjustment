function file=prnc_run(revision_root,destination,opt)
% Extend native focal-chart coverage using existing physical camera estimates.
% No calls to a camera solver or random observation generator exist here.
if nargin<3,opt=prnc_config('paper');end
wall_started=tic;
root=fileparts(mfilename('fullpath'));addpath(root);
assert(opt.nominal==.95,'Tables 4/5 require nominal 95%%');
validateattributes(opt.max_new_batches,{'numeric'},{'scalar','positive'});
fprintf('Loading PR provenance and original metadata; checking input checksum...\n');
[o,pr,source,provenance]=prnc.IO.sources(revision_root,opt);
destination=prnc.IO.canonical(destination);
assert(~strcmp(destination,fileparts(source))&&~startsWith(source,[destination filesep]),'Destination contains original source');
assert(~startsWith(provenance.pr_file,[destination filesep]),'Destination contains PR input');
for s={'','checkpoints','tables','figures'},p=fullfile(destination,s{1});if ~isfolder(p),mkdir(p);end,end
lock=fullfile(destination,'RUNNING.lock');lk=java.io.File(lock);
assert(lk.createNewFile(),'PRNC:Busy','RUNNING.lock exists. Stop the other run. Remove a stale lock only after MATLAB has stopped.');
unlock=onCleanup(@()prnc.IO.remove(lock)); %#ok<NASGU>
jobs=select_jobs(o,opt);signature=prnc.IO.manifest(root);
identity=rmfield(opt,{'max_new_batches','make_figures','dpi','original_file'});
selected=cell(1,numel(jobs));
for i=1:numel(jobs)
 c=o.conditions{jobs(i).index};entries=[{c.design} c.batches];
 selected{i}=struct('prefix',c.prefix,'methods',{jobs(i).methods},...
  'hashes',{cellfun(@(a)a.sha256,entries,'UniformOutput',false)});
end
token=prnc.IO.hash(jsonencode(struct('provenance',provenance,'options',identity,'code',{signature},'selected',{selected})));
cp=fullfile(destination,'checkpoint.mat');file=fullfile(destination,'output.mat');
if isfile(cp)
 a=load(cp,'state');assert(strcmp(a.state.token,token),'PRNC:ResumeMismatch','Source, settings or code changed. Use a NEW destination.');
else
 assert(~isfile(file),'Unidentified output exists; choose another destination');
 state=struct('token',token,'provenance',provenance,'options',opt,'complete',false);
 prnc.IO.save(cp,'state',state);
end
if isfile(file)
 a=load(file,'output');assert(strcmp(a.output.token,token)&&a.output.complete,'Existing output identity mismatch');
 prnc.Reports.write(a.output,destination,opt);fprintf('Reused completed analysis: %s\n',file);return
end
records={};new_batches=0;started=tic;
fprintf('READ-ONLY postprocessing: %d conditions; no new fits. Source: %s\n',numel(jobs),source);
for i=1:numel(jobs)
 job=jobs(i);c=o.conditions{job.index};d=prnc.IO.read(source,c.design);
 assert(isequal(d.spec,c.spec),'Design and condition specifications disagree');
 [found,mi]=ismember(job.methods,d.methods);assert(all(found),'Required source method missing');
 nb=min(numel(c.batches),opt.max_batches_per_condition);parts=cell(numel(mi),nb);
 for j=1:nb
  key=sprintf('c%03d_b%04d',job.index,j);[hit,value]=prnc.IO.cached(destination,key,token);
  if ~hit
   b=prnc.IO.read(source,c.batches{j},{'trial_id','errors','covariance_native','cameras','valid'});
   value=cell(1,numel(mi));
   for m=1:numel(mi),value{m}=prnc.Stats.batch(b,mi(m),d.geometry.truth_camera,opt);end
   prnc.IO.put(destination,key,token,value);new_batches=new_batches+1;
  end
  for m=1:numel(mi),parts{m,j}=value{m};end
  if mod(j,10)==0||j==nb||(~hit&&new_batches==1)
   fprintf('Read/analyse %d/%d | %s | batch %d/%d | %.1f s\n',i,numel(jobs),c.prefix,j,nb,toc(started));
  end
  if ~hit&&new_batches>=opt.max_new_batches
   fprintf('Saved %d new batches. Re-run the SAME folder/settings to continue.\n',new_batches);file=cp;return
  end
 end
 for m=1:numel(mi)
  r=prnc.Stats.combine(parts(m,:));r.condition=c.prefix;r.spec=c.spec;r.method=job.methods{m};
  r.role=job.role;r.regime=job.regime;r.geometry_id=c.spec.geometry_id;
  sm=o.summaries{job.index};sm=sm.method{mi(m)};sm.trial_ids=o.summaries{job.index}.trial_ids;assert(strcmp(sm.label,r.method),'Source method order mismatch');
  r.source_check=prnc.Stats.validate_source(r,sm,opt);r.summary=prnc.Stats.summary(r);
  if strcmp(opt.profile,'paper'),assert(r.source_check.complete_condition&&numel(r.trial_ids)==c.spec.N);end
  records{end+1}=r; %#ok<AGROW>
 end
end
output=struct('schema_version','pr-native-chart-1.0','complete',true,...
 'paper_ready',strcmp(opt.profile,'paper'),'profile',opt.profile,'token',token,...
 'created_utc',char(datetime('now','TimeZone','UTC')),'new_camera_fits',0,...
 'provenance',provenance,'options',opt,'code_manifest',{signature},'source_entry_manifest',{selected},...
 'nominal',opt.nominal,'df',10,'threshold',2*gammaincinv(opt.nominal,5),...
 'rotation_chart','Same estimate-centred left rotation chart for BOTH focal coordinates',...
 'method','Finite focal error fhat-f0; full covariance transformed at fhat, retaining all cross-covariances',...
 'records',{records},'analysis_seconds_before_reports',toc(started));
output.table4=prnc.Reports.table4(records,pr);
[output.table5,output.population]=prnc.Reports.population(records,o,opt);
output.condition_summary=prnc.Reports.condition_table(records);
output.wall_seconds_before_export=toc(wall_started);
output.validation=struct('all_saved_log_statistics_reproduced',true,...
 'all_consumed_payload_checksums_verified',true,'all_direct_f_congruence_checks_passed',true,...
 'all_population_geometries_used',strcmp(opt.profile,'paper'),'original_manuscript_edited',false);
% Detect source changes during this run; input files are never opened writable.
s=dir(source);assert(s.bytes==provenance.source_bytes&&s.datenum==provenance.source_datenum,'Original source changed while reading');
prnc.IO.save(file,'output',output);
state=struct('token',token,'provenance',provenance,'options',opt,'complete',true);
prnc.IO.save(cp,'state',state);
prnc.Reports.write(output,destination,opt);
fprintf('Complete; no new camera fits. %s\n',file);
end

function jobs=select_jobs(o,opt)
jobs=struct('index',{},'methods',{},'role',{},'regime',{});
% Match physical conditions, not output magnitude or a preferred outcome.
for i=1:numel(o.conditions)
 c=o.conditions{i};s=c.spec;methods={};role='';regime=0;
 if strcmp(c.suite,'J09')&&strcmp(s.kind,'patch')&&s.n==30&&abs(s.noise_scale-1)<1e-12
  if abs(s.depth_spread-.15)<1e-12,role='Reference';methods={'GH_LOCAL','GH_FULL'};
  elseif abs(s.depth_spread-.02)<1e-12,role='Narrow reference';methods={'GH_FULL'};end
 elseif strcmp(c.suite,'J09')&&strcmp(s.kind,'global')&&s.n==60
  role='Global 60';methods={'GH_LOCAL'};
 elseif strcmp(c.suite,'J10')&&s.n==30&&abs(s.depth_spread-.02)<1e-12&&abs(s.noise_scale-1)<1e-12
  role='Narrow noise sweep';methods={'GH_FULL'};
 elseif strcmp(c.suite,'J11')&&strcmp(s.sweep,'M4')
  role='Omitted global';methods={'omit_global'};
 elseif strcmp(c.suite,'J12')&&ismember(s.x,opt.population_regimes)&&s.geometry_id<=opt.max_geometries
  role='Population';methods={'GH_FULL'};regime=s.x;
 end
 if ~isempty(methods),jobs(end+1)=struct('index',i,'methods',{methods},'role',role,'regime',regime);end %#ok<AGROW>
end
for role={'Reference','Narrow reference','Global 60','Narrow noise sweep','Omitted global'}
 assert(nnz(strcmp({jobs.role},role{1}))==1,'Missing or ambiguous condition: %s',role{1});
end
assert(isequal(opt.population_regimes,1:4),'Table 5 requires all four prespecified regimes');
for regime=1:4
 ix=find([jobs.regime]==regime);ids=arrayfun(@(j)o.conditions{j.index}.spec.geometry_id,jobs(ix));
 expected=1:min(o.config.j12.geometries,opt.max_geometries);
 assert(isequal(sort(ids),expected),'Missing/duplicate population geometries in regime %d',regime);
end
end
