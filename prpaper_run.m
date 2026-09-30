function file=prpaper_run(mode,opt)
%PRPAPER_RUN Unified resumable MATLAB pipeline; never silently uses snapshots.
% output.mat contains all compact numerical inputs, analyses, table data and
% figure datasets. Original full archives remain at raw_stage_paths.
root=prpaper_setup();mode=char(mode);
restore_public_path=onCleanup(@()prpaper_setup()); %#ok<NASGU>
if nargin<2,opt=prpaper_config('paper');end
resuming=strcmp(mode,'resume');
if resuming
 destination=canonical(opt.destination);cp=fullfile(destination,'checkpoint.mat');
 a=load(cp,'state');state=a.state;budget=opt.max_batches;opt=state.options;
 opt.max_batches=budget;mode=state.mode;
else
 assert(ismember(mode,{'reference','paper','existing','figures'}),'Unknown mode.');
 validate_options(opt);
 if isempty(opt.destination)
  opt.destination=fullfile(root,'runs',[mode '_' opt.profile '_' datestr(now,'yyyymmdd_HHMMSS_FFF')]);
 end
 destination=canonical(opt.destination);opt.destination=destination;
 cp=fullfile(destination,'checkpoint.mat');
 if isfile(cp)
  a=load(cp,'state');state=a.state;
  assert(strcmp(state.mode,mode)&&strcmp(state.identity,identity(mode,opt,root)),...
   'PRPAPER:ResumeMismatch','Options, source identity or code changed. Choose a NEW destination.');
 else
  assert(~isfile(fullfile(destination,'output.mat')),'Unidentified output exists; choose a new destination.');
  assert(~strcmp(destination,root),'Do not use the package root as a run destination.');
  if ~isempty(opt.source_file)
   sf=canonical(opt.source_file);
   assert(~strcmp(fileparts(sf),destination)&&~startsWith(sf,[destination filesep]),...
    'PRPAPER:SourceSafety','Destination must not contain or equal the existing source folder.');
  end
  state=struct('schema_version','prpaper-pipeline-1.0','mode',mode,'profile',opt.profile,...
   'identity',identity(mode,opt,root),'options',opt,'created_utc',utc(),...
   'complete',false,'paper_ready',false,'stages',struct());
 end
end
validate_options(opt);
state.options=opt;state.complete=false;state.paper_ready=false;
assert(strcmp(state.identity,identity(mode,opt,root)),'PRPAPER:ResumeMismatch',...
 'Package code, inputs or saved settings changed. Use a new destination.');
if ~isfolder(destination),mkdir(destination);end
lock=fullfile(destination,'RUNNING.lock');lk=java.io.File(lock);
assert(lk.createNewFile(),'PRPAPER:Busy',...
 'RUNNING.lock exists. Stop the other run first; remove a stale lock only after MATLAB stops.');
unlock=onCleanup(@()remove_file(lock)); %#ok<NASGU>
atomic(cp,'state',state);
paths=stage_paths(destination,opt);
if strcmp(mode,'reference'),planned={'collect','analyze','tables','figures'};
elseif strcmp(mode,'figures'),planned={'collect','analyze','tables','figures'};
elseif strcmp(mode,'existing'),planned={'postprocess','rotation','bias','reparameterization','native','collect','analyze','tables','figures'};
else,planned={'base','base_analysis','base_figures','postprocess','rotation','bias','reparameterization','native','collect','analyze','tables','figures'};end
allstages={'base','base_analysis','base_figures','postprocess','rotation','bias','reparameterization','native','collect','analyze','tables','figures'};
if ~isempty(opt.stages)
 assert(all(ismember(opt.stages,allstages)),'Unknown stage name.');
 planned=allstages(ismember(allstages,opt.stages));
end
if ~opt.make_figures,planned(strcmp(planned,'figures'))=[];end
file=cp;
for k=1:numel(planned)
 stage=planned{k};
 if isfield(state.stages,stage)&&strcmp(state.stages.(stage).status,'complete')
  artifact=fullfile(destination,state.stages.(stage).artifact);
  assert(isfile(artifact),'PRPAPER:MissingArtifact','Completed stage artifact missing: %s',artifact);
  fprintf('[%s] reuse complete\n',stage);continue;
 end
 state.stages.(stage)=struct('status','running','started_utc',utc(),'finished_utc','','artifact','','message','');
 atomic(cp,'state',state);fprintf('\n=== %s | %s | %s ===\n',stage,mode,opt.profile);
 try
  completed=true;artifact='';
  switch stage
   case 'base'
    assert(strcmp(mode,'paper'),'Existing/reference modes cannot run source simulation.');
    bd=fileparts(paths.base);
    if isfile(paths.base)
     b=jog2.Store.metadata(paths.base);completed=b.meta.complete;
     if completed&&(~isfield(b,'validation')||~isfield(b.validation,'integrity')||~b.validation.integrity.passed)
      jog_check_output_v2(paths.base,'strict');
     end
    elseif isfile(fullfile(bd,'checkpoint.mat'))
     artifact=run_jog_v2('resume',bd,'MaxBatches',opt.max_batches);
     b=jog2.Store.metadata(artifact);completed=b.meta.complete;
    else
     artifact=run_jog_v2(opt.base,bd,'MaxBatches',opt.max_batches);
     b=jog2.Store.metadata(artifact);completed=b.meta.complete;
    end
    if completed,artifact=paths.base;elseif isempty(artifact),artifact=fullfile(bd,'checkpoint.mat');end
   case 'base_analysis'
    assert(strcmp(mode,'paper'),'Existing input is read-only; analyze a copied raw run separately.');
    b=load_base(paths.base,false);
    if ~b.meta.analysis_complete,jog_analyze_v2(paths.base,{'D01','D02','D03','D04','J15'},'MaxConditions',opt.max_batches);end
    b=jog2.Store.metadata(paths.base);completed=b.meta.analysis_complete;artifact=paths.base;
   case 'base_figures'
    assert(strcmp(mode,'paper'),'Existing input is read-only.');load_base(paths.base,true);
    % Retain all computed observation/fit/target data; render only legacy
    % assets consumed by the publication adapter. PR target figures use the
    % extended postprocess results, so dozens of old F15 panels are redundant.
    assets={'F01','F02','F03','F04','F07','F08','F09','F10','F11','F12','F13','F14'};
    jog_make_figures_v2(paths.base,'paper',assets);artifact=paths.base;
   case {'postprocess','rotation','bias','reparameterization'}
    load_base(paths.base,true);rp=opt.revision;rp.source_file=paths.base;rp.max_tasks=opt.max_batches;
    rp.make_figures=false;artifact=paths.(stage);
    if isfile(artifact)
     assert_revision(artifact,stage,paths.base);
    else
     folder=fileparts(artifact);
     switch stage
      case 'postprocess',artifact=pr_run_postprocess(paths.base,folder,rp);
      case 'rotation',artifact=pr_run_additional(paths.base,folder,rp);
      case 'bias',artifact=pr_run_bias(paths.base,folder,rp);
      case 'reparameterization',artifact=pr_run_reparameterization(paths.base,folder,rp);
     end
    end
    completed=stage_complete(artifact);
    if completed,assert_revision(artifact,stage,paths.base);end
   case 'native'
    assert_revision(paths.postprocess,'postprocess',paths.base);
    artifact=paths.native;
    if isfile(artifact),assert_native(artifact,paths.base);
    else
     np=opt.native;np.original_file=paths.base;np.max_new_batches=opt.max_batches;np.make_figures=false;
     artifact=prnc_run(paths.postprocess,fileparts(paths.native),np);
    end
    completed=stage_complete(artifact);
    if completed,assert_native(artifact,paths.base);end
   case 'collect'
    if strcmp(mode,'reference'),DATA=prpaper_collect(opt.reference_dir);
    elseif strcmp(mode,'figures')
     old=load(opt.source_file,'output');assert(isfield(old,'output')&&isfield(old.output,'data'),'Expected unified output.mat.');DATA=old.output.data;
    else,DATA=prpaper_collect(paths);end
    DATA.run=struct('mode',mode,'profile',opt.profile,'created_utc',utc(),...
     'reference_snapshot',strcmp(mode,'reference'),'camera_fitting_permitted',ismember(mode,{'paper','existing'}),...
     'experiment_identifier_map',{{'E01','J09';'E02','J10';'E03','J11';'E04','J12';'E05','J13';'E06','J14';'E07','J15'}});
    atomic(fullfile(destination,'collected.mat'),'DATA',DATA);artifact=fullfile(destination,'collected.mat');
   case 'analyze'
    a=load(fullfile(destination,'collected.mat'),'DATA');analysis=prpaper_analyze(a.DATA,opt);
    atomic(fullfile(destination,'analysis.mat'),'analysis',analysis);artifact=fullfile(destination,'analysis.mat');
   case 'tables'
    a=load(fullfile(destination,'collected.mat'),'DATA');b=load(fullfile(destination,'analysis.mat'),'analysis');
    tables=prpaper_tables(a.DATA,b.analysis,destination,opt);
    atomic(fullfile(destination,'table_data.mat'),'tables',tables);artifact=fullfile(destination,'table_data.mat');
   case 'figures'
    a=load(fullfile(destination,'collected.mat'),'DATA');b=load(fullfile(destination,'analysis.mat'),'analysis');
    fopt=opt;fopt.visible=opt.figure_visible;fopt.formats={'png','fig'};if opt.export_pdf,fopt.formats={'png','pdf','fig'};end
    fd=fullfile(destination,'figures');figures=prpaper_figures(a.DATA,b.analysis,fd,fopt);
    figure_product=struct('manifest',figures,'data',struct());
    for j=1:numel(figures),q=load(fullfile(fd,figures(j).data_file),'payload');figure_product.data.(figures(j).id)=q.payload;end
    atomic(fullfile(destination,'figure_data.mat'),'figure_product',figure_product);artifact=fullfile(destination,'figure_data.mat');
  end
  state.stages.(stage).artifact=relative(destination,artifact);
  if completed,state.stages.(stage).status='complete';state.stages.(stage).finished_utc=utc();
  else,state.stages.(stage).status='partial';state.stages.(stage).message='Budget reached; saved tasks will be reused.';end
  atomic(cp,'state',state);
  if ~completed,fprintf('Paused at %s. RUN_RESUME(''%s'') continues this run.\n',stage,destination);return;end
 catch ME
  state.stages.(stage).status='failed';state.stages.(stage).message=ME.message;
  state.stages.(stage).error_identifier=ME.identifier;atomic(cp,'state',state);rethrow(ME);
 end
end
% A stage-only run is never called a complete manuscript reproduction.
required={'collect','analyze','tables'};if opt.make_figures,required{end+1}='figures';end
allready=all(cellfun(@(s)isfield(state.stages,s)&&strcmp(state.stages.(s).status,'complete'),required));
if allready
 a=load(fullfile(destination,'collected.mat'),'DATA');b=load(fullfile(destination,'analysis.mat'),'analysis');t=load(fullfile(destination,'table_data.mat'),'tables');
 output=struct('schema_version','prpaper-output-1.0','package_version','1.1.0','complete',true,...
  'mode',mode,'profile',a.DATA.base.config.profile,'created_utc',utc(),'data',a.DATA,'analysis',b.analysis,'tables',t.tables,...
  'raw_stage_paths',struct(),'stage_status',state.stages,'source_code_manifest',{code_manifest(root)});
 if opt.make_figures,f=load(fullfile(destination,'figure_data.mat'),'figure_product');output.figures=f.figure_product.manifest;output.figure_data=f.figure_product.data;end
 if ~ismember(mode,{'reference','figures'})
  fn=fieldnames(paths);for j=1:numel(fn),output.raw_stage_paths.(fn{j})=relative(destination,paths.(fn{j}));end
 elseif strcmp(mode,'figures')
  output.upstream_output=relative(destination,opt.source_file);
  old=load(opt.source_file,'output');
  if isfield(old.output,'raw_stage_paths')
   fn=fieldnames(old.output.raw_stage_paths);
   for j=1:numel(fn),oldpath=fullfile(fileparts(canonical(opt.source_file)),old.output.raw_stage_paths.(fn{j}));output.raw_stage_paths.(fn{j})=relative(destination,oldpath);end
  end
 end
 output.paper_ready=paper_ready(a.DATA)&&opt.make_figures;
 output.scope='Numerical figure/table data are embedded. Full observation/fit archives remain at raw_stage_paths; reference mode contains compact retained evidence only.';
 file=fullfile(destination,'output.mat');atomic(file,'output',output);
 state.complete=true;state.paper_ready=output.paper_ready;state.completed_utc=utc();atomic(cp,'state',state);
 fprintf('\nSaved unified output: %s\n',file);
else
 fprintf('\nRequested stages finished; full manuscript products are not yet complete.\n');
end
end

function yes=stage_complete(file)
% Do not enumerate a MAT archive with WHOS: its custom /jog_payload group is
% intentionally not a MATLAB variable and can trip MAT-file enumeration.
% Stage launchers return checkpoint.mat on a deliberate bounded pause.
[~,name,ext]=fileparts(file);yes=false;
if strcmpi([name ext],'checkpoint.mat'),return;end
a=load(file,'output');
assert(isfield(a,'output')&&isstruct(a.output)&&isfield(a.output,'complete'),...
 'PRPAPER:StageOutput','Completed-stage file has no valid output metadata: %s',file);
assert(isscalar(a.output.complete),'Invalid completion flag in stage output.');
yes=logical(a.output.complete);
end
function ready=paper_ready(D)
ready=isfield(D.base,'config')&&strcmp(D.base.config.profile,'paper')&&...
 D.base.config.mc_nonlinear==2000&&D.base.config.j12.geometries==20&&...
 D.base.config.j12.maps==200&&isfield(D.native,'paper_ready')&&D.native.paper_ready;
if ~ready,return;end
expected=jog_config_v2('paper');
fields={'master_seed','revision_seed','analysis_seed','mc_linear','mc_plane','mc_nonlinear',...
 'identity_cases','nominal','camera','linear','plane','nonlinear','solver','j10','j11','j12','j13','j14','j15','enabled'};
for k=1:numel(fields),ready=ready&&isequaln(D.base.config.(fields{k}),expected.(fields{k}));end
if ~ready,return;end
% Smoke/truncated bias traces or selected fit subsets are never paper-ready.
G=D.revision.bias.geometries;
if numel(G)~=4,ready=false;return;end
for k=1:numel(G),if iscell(G),g=G{k};else,g=G(k);end;ready=ready&&all(g.complete_trace);end
ready=ready&&size(D.focal.error_log_truth_minus_fit,1)==2000;
R=D.revision.rotation.conditions;ready=ready&&numel(R)==6;
for k=1:numel(R),if iscell(R),r=R{k};else,r=R(k);end;ready=ready&&numel(r.trial_ids)==2000;end
T=D.revision.postprocess.target_conditions;
for k=1:numel(T),if iscell(T),t=T{k};else,t=T(k);end;ready=ready&&t.complete_source;end
end
function validate_options(opt)
assert(ismember(opt.profile,{'paper','pilot','smoke'}),'Unknown profile.');
validateattributes(opt.max_batches,{'numeric'},{'scalar','positive'});
assert(isinf(opt.max_batches)||fix(opt.max_batches)==opt.max_batches,'Budget must be an integer or Inf.');
assert(~opt.allow_incomplete,'Incomplete experiment evidence cannot be published as a full package.');
end
function paths=stage_paths(destination,opt)
paths=struct('base',fullfile(destination,'raw','base','output.mat'),...
 'postprocess',fullfile(destination,'raw','postprocess','output.mat'),...
 'rotation',fullfile(destination,'raw','rotation','output.mat'),...
 'bias',fullfile(destination,'raw','bias','output.mat'),...
 'reparameterization',fullfile(destination,'raw','reparameterization','output.mat'),...
 'native',fullfile(destination,'raw','native','output.mat'));
if ~isempty(opt.source_file),paths.base=canonical(opt.source_file);end
if ~isempty(opt.revision_root)
 r=canonical(opt.revision_root);
 if isfile(r),paths.postprocess=r;
 else
  names={'postprocess','rotation','bias','reparameterization'};
  legacy={'postprocess_paper','strong_rotation_paper','bias_paper','reparameterization_paper'};
  for k=1:numel(names)
   candidates={fullfile(r,legacy{k},'output.mat'),fullfile(r,'results',legacy{k},'output.mat'),fullfile(r,names{k},'output.mat')};
   if strcmp(names{k},'rotation'),candidates=[candidates {fullfile(r,'rotation_paper','output.mat'),fullfile(r,'results','rotation_paper','output.mat')}];end
   ix=find(cellfun(@isfile,candidates),1);if ~isempty(ix),paths.(names{k})=candidates{ix};end
  end
 end
end
if ~isempty(opt.native_file),paths.native=canonical(opt.native_file);end
end
function b=load_base(file,analysis_required)
assert(isfile(file),'Missing original archive: %s',file);b=jog2.Store.metadata(file);
assert(b.meta.complete,'Original simulation is incomplete.');
if analysis_required,assert(b.meta.analysis_complete,'Original condition analysis is incomplete.');end
end
function assert_revision(file,stage,source)
a=load(file,'output');p=a.output;b=load_base(source,true);
names=struct('postprocess','postprocess','rotation','strong_rotation','bias','second_order_bias','reparameterization','direct_focal_diagnostic');
assert(p.complete&&strcmp(p.stage,names.(stage)),'PR stage is incomplete or has the wrong type.');
assert(strcmp(p.source_run,b.meta.run_id),'PR result belongs to a different original run.');
end
function assert_native(file,source)
a=load(file,'output');b=load_base(source,true);
assert(a.output.complete&&strcmp(a.output.provenance.source_run,b.meta.run_id),'Native result incomplete or from another run.');
end
function t=identity(mode,opt,root)
q=opt;q=rmfield(q,{'destination','max_batches','dpi','make_figures','figure_visible','export_pdf','stages'});
% Explicit inputs have immutable logical identities. The original MAT can be
% very large, so do not hash the whole archive at every batch/resume.
sources=struct();
if strcmp(mode,'reference')
 p=fullfile(opt.reference_dir,'reference_data.mat');assert(isfile(p),'Missing bundled reference_data.mat');sources.reference=jog2.Util.filehash(p);
 a=load(p,'DATA');
 if isfield(a.DATA,'provenance')&&isfield(a.DATA.provenance,'reference_parts')
  parts=a.DATA.provenance.reference_parts;if ~iscell(parts),parts=cellstr(parts);end;sources.reference_parts=cell(numel(parts),2);
  for k=1:numel(parts),partpath=fullfile(opt.reference_dir,parts{k});assert(isfile(partpath),'Missing reference component: %s',partpath);sources.reference_parts(k,:)={parts{k},jog2.Util.filehash(partpath)};end
  sources.reduced=jog2.Util.filehash(fullfile(opt.reference_dir,'reference_reduced_draws.mat'));
 end
elseif ~isempty(opt.source_file)
 p=canonical(opt.source_file);assert(isfile(p),'Explicit source not found: %s',p);
 a=load(p,'output');o=a.output;
 if isfield(o,'meta'),d=dir(p);sources.base=struct('run_id',o.meta.run_id,'config_hash',o.meta.config_hash,'pack_identity',o.meta.pack_identity,'bytes',d.bytes,'datenum',d.datenum);
 else,d=dir(p);sources.unified=struct('bytes',d.bytes,'datenum',d.datenum,'schema',o.schema_version);end
end
% External completed PR/native inputs are read-only: detect replacement or
% modification without hashing a multi-gigabyte archive on every resume.
if strcmp(mode,'existing')
 pp=stage_paths(canonical(opt.destination),opt);names={'postprocess','rotation','bias','reparameterization','native'};
 for k=1:numel(names)
  p=pp.(names{k});
  if isfile(p)&&~startsWith(canonical(p),[canonical(opt.destination) filesep])
   a=load(p,'output');d=dir(p);sources.(names{k})=struct('token',a.output.token,'bytes',d.bytes,'datenum',d.datenum);
  end
 end
end
sources.reduced_resampling=jog2.Util.filehash(fullfile(root,'data','resampling','reduced_bootstrap_counts.mat'));
t=jog2.Util.hash(jsonencode(struct('mode',mode,'options',q,'sources',sources,'code',{code_manifest(root)})));
end
function c=code_manifest(root)
files=dir(fullfile(root,'*.m'));
for d={'src','engines'},files=[files;dir(fullfile(root,d{1},'**','*.m'))];end %#ok<AGROW>
c=cell(numel(files),2);
for k=1:numel(files),p=fullfile(files(k).folder,files(k).name);c(k,:)={relative(root,p),jog2.Util.filehash(p)};end
[~,ix]=sort(c(:,1));c=c(ix,:);
end
function p=canonical(p),p=char(java.io.File(p).getCanonicalPath());end
function r=relative(root,p),r=char(java.io.File(root).toPath().relativize(java.io.File(canonical(p)).toPath()).toString());end
function atomic(p,name,value)
% Compact MATLAB-v7 compression avoids HDF5 object overhead for the many
% small nested numeric arrays in publication metadata. Large variables retain
% v7.3 support; the engine raw archives use their own unchanged storage code.
info=whos('value');format='-v7';
if info.bytes>=1.5*1024^3,format='-v7.3';end
partial=[p '.partial.mat'];payload=struct();payload.(name)=value;
save(partial,'-struct','payload',format);
[ok,msg]=movefile(partial,p,'f');assert(ok,msg);
end
function t=utc(),t=jog2.Util.utc();end
function remove_file(p),if isfile(p),delete(p);end,end
