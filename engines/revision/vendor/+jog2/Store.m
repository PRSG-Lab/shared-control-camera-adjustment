classdef Store
methods(Static)
function o=metadata(file)
 if isfolder(file),file=fullfile(file,'output.mat');end
 if ~jog2.Archive.isArchive(file)&&jog2.Archive.rootCount(file)>1000
  error('jog2:LegacyFlatMAT','Legacy flat MAT directory is too large. Use jog_recover_v2 on its run folder/checkpoint.mat; do not load the flat output again.');
 end
 s=load(file,'output');o=s.output;
end
function saveMetadata(file,o)
 assert(jog2.Archive.isArchive(file),'Upgrade flat v2.0 output with jog_recover_v2 first');
 output=o;save(file,'output','-append');
end
function o=create(cfg,folder)
 assert(~exist(fullfile(folder,'checkpoint.mat'),'file')&&~exist(fullfile(folder,'output.mat'),'file'),'Existing run: use resume');
 if ~exist(folder,'dir'),mkdir(folder);end;mkdir(fullfile(folder,'checkpoints'));
 src=jog2.Util.sources();created=jog2.Util.utc();hash=jog2.Util.hash([created jsonencode(cfg) tempname]);
 o=struct('schema_version','jog-output-2.1','config',cfg,'conditions',{{}},'legacy',struct(),...
 'summaries',{{}},'diagnostics',struct(),'figure_data',struct(),'figure_manifest',struct([]),...
 'meta',struct('run_id',['run_' hash(1:12)],'created_utc',created,'completed_utc','','status','running',...
 'complete',false,'analysis_complete',false,'matlab_release',version,'platform',computer,'toolbox_inventory',ver,...
 'source_code',src,'source_hash',jog2.Util.hash(jsonencode(src)),'config_hash',jog2.Util.hash(jsonencode(cfg)),...
 'source_runs',{cfg.source_runs}),'data_index',struct([]),'progress',struct('completed_suites',{{}}));
end
function checkpoint(o,folder)
 jog2.Util.saveAtomic(fullfile(folder,'checkpoint.mat'),'output',o);
end
function [entry,shard]=write(folder,prefix,value,tag)
 if nargin<4,tag='data';end
 shard=fullfile('checkpoints',[prefix '.mat']);file=fullfile(folder,shard);vars=struct();
 if strcmp(tag,'batch'),fn=fieldnames(value);for k=1:numel(fn),vars.([prefix '_' fn{k}])=value.(fn{k});end
 else,vars.(prefix)=value;end
 tmp=[file '.partial.mat'];save(tmp,'-struct','vars','-v7.3');movefile(tmp,file,'f');
 entry=struct('prefix',prefix,'file',shard,'sha256',jog2.Util.filehash(file),'bytes',dir(file).bytes,'kind',tag);
end
function v=read(file,e)
 if isfolder(file),file=fullfile(file,'checkpoint.mat');end
 if jog2.Archive.isArchive(file),v=jog2.Archive.read(file,e);return;end
 if endsWith(file,'checkpoint.mat'),src=fullfile(fileparts(file),e.file);assert(exist(src,'file')==2,'Missing checkpoint shard');
 else,src=file;end
 assert(jog2.Archive.rootCount(src)<1000,'Do not read legacy flat final MAT; recover its checkpoint');
 if isfield(e,'variables'),s=load(src,e.variables{:});else,s=load(src);end
 v=jog2.Archive.unpack(s,e);
end
function d=design(file,condition)
 d=jog2.Store.read(file,condition.design);
end
function out=finalize(folder,sourceFiles)
 if nargin<2,sourceFiles={};end
 out=jog2.Store.packCheckpoint(fullfile(folder,'checkpoint.mat'),folder,sourceFiles,Inf);
end
function out=packCheckpoint(checkpoint,destination,sourceFiles,maxEntries)
 if nargin<3,sourceFiles={};end;if nargin<4,maxEntries=Inf;end
 original=jog2.Store.metadata(checkpoint);jog2.Store.assertRawComplete(original);
 o=original;o.schema_version='jog-output-2.1';o.summaries={};o.figure_data=struct();o.figure_manifest=struct([]);o.diagnostics=struct();o.data_index=struct([]);
 srcEntries=jog2.Store.entries(o);routes=cellfun(@(e)fullfile(fileparts(checkpoint),e.file),srcEntries,'UniformOutput',false);
 sourcesAreArchives=false(size(routes));o.meta.recovery_source_checkpoint=checkpoint;
 for j=1:numel(sourceFiles)
  sf=sourceFiles{j};q=jog2.Store.metadata(sf);assert(q.meta.complete&&jog2.Archive.isArchive(sf),'Source must be complete v2.1 archive');
  ee=jog2.Store.entries(q);srcEntries=[srcEntries ee];routes=[routes repmat({sf},size(ee))];sourcesAreArchives=[sourcesAreArchives true(size(ee))];
  o.conditions=[o.conditions q.conditions];names=fieldnames(q.legacy);
  for z=1:numel(names),nm=names{z};if isfield(o.legacy,nm),nm=[nm '_source' num2str(j)];end;o.legacy.(nm)=q.legacy.(names{z});end
  if isfield(q,'extra_datasets'),if ~isfield(o,'extra_datasets'),o.extra_datasets={};end;o.extra_datasets=[o.extra_datasets q.extra_datasets];end
  o.meta.imported_sources{j}=q.meta;o.meta.imported_configs{j}=q.config;
 end
 prefixes=cellfun(@(e)e.prefix,srcEntries,'UniformOutput',false);assert(numel(unique(prefixes))==numel(prefixes),'Duplicate source namespace');
 identity=jog2.Util.hash(jsonencode(struct('run',original.meta.run_id,'config',original.meta.config_hash,...
 'prefixes',{prefixes},'hashes',{cellfun(@(e)e.sha256,srcEntries,'UniformOutput',false)})));
 o=jog2.Store.normalize(o);o.meta.storage_format='MAT-shard-bytes-v1';o.meta.storage_source_code=jog2.Util.sources();o.meta.storage_source_hash=jog2.Util.hash(jsonencode(o.meta.storage_source_code));
 o.meta.pack_identity=identity;o.meta.complete=false;o.meta.analysis_complete=false;o.meta.status='packing';
 if ~exist(destination,'dir'),mkdir(destination);end
 out=fullfile(destination,'output.mat');partial=fullfile(destination,'output.packing.mat');
 if exist(out,'file')
  existing=jog2.Store.metadata(out);assert(isfield(existing.meta,'pack_identity')&&strcmp(existing.meta.pack_identity,identity),'Existing different output: choose a new destination');
  assert(existing.meta.complete,'Incomplete final archive');fprintf('Reusing completed raw archive: %s\n',out);return;
 end
 if exist(partial,'file'),prior=jog2.Store.metadata(partial);assert(strcmp(prior.meta.pack_identity,identity),'Different packing source');
 else,jog2.Archive.create(partial,o);end
 total=numel(srcEntries);tt=tic;done=0;
 for k=1:total
  e=srcEntries{k};assert(~isempty(e.sha256),'Source entry requires checksum');
  if jog2.Archive.ready(partial,e),continue;end
  if sourcesAreArchives(k),[tmp,clean]=jog2.Archive.extract(routes{k},e);jog2.Archive.putFile(partial,e,tmp);clear clean;
  else,assert(exist(routes{k},'file')==2,'Missing raw source: %s',routes{k});jog2.Archive.putFile(partial,e,routes{k});end
  done=done+1;
  if mod(k,25)==0||k==total,fprintf('Pack %d/%d | %.1f s elapsed\n',k,total,toc(tt));end
  if done>=maxEntries,out=partial;fprintf('Packing checkpoint: %s\n',partial);return;end
 end
 for k=1:total,assert(jog2.Archive.ready(partial,srcEntries{k}),'Incomplete archive');end
 o.meta.complete=true;o.meta.status='raw_complete';o.meta.completed_utc=jog2.Util.utc();o.meta.pack_seconds=toc(tt);
 jog2.Store.saveMetadata(partial,o);movefile(partial,out,'f');
end
function assertRawComplete(o)
 required=setdiff(o.config.enabled,{'J15','J16'});assert(all(ismember(required,o.progress.completed_suites)),...
 'jog2:IncompleteSimulation','Simulation checkpoint is incomplete. Recovery does not run missing camera fits.');
 for k=1:numel(o.conditions)
  c=o.conditions{k};ids=[];for j=1:numel(c.batches),assert(isfield(c.batches{j},'trial_ids'),'Missing trial index');ids=[ids c.batches{j}.trial_ids];end
  assert(isequal(sort(ids),1:c.spec.N)&&numel(unique(ids))==numel(ids),'Missing or duplicate raw trials');
 end
end
function o=normalize(o)
 for i=1:numel(o.conditions)
  c=o.conditions{i};c.design=jog2.Archive.normalize(c.design);
  c.batches=cellfun(@jog2.Archive.normalize,c.batches,'UniformOutput',false);
  if isfield(c,'target_batches'),c.target_batches=cellfun(@jog2.Archive.normalize,c.target_batches,'UniformOutput',false);end
  o.conditions{i}=c;
 end
 names=fieldnames(o.legacy);for i=1:numel(names),o.legacy.(names{i})=jog2.Archive.normalize(o.legacy.(names{i}));end
 if isfield(o,'extra_datasets'),o.extra_datasets=cellfun(@jog2.Archive.normalize,o.extra_datasets,'UniformOutput',false);end
end
function e=entries(o)
 e={};for i=1:numel(o.conditions),c=o.conditions{i};e{end+1}=c.design;e=[e c.batches];if isfield(c,'target_batches'),e=[e c.target_batches];end,end
 n=fieldnames(o.legacy);for k=1:numel(n),e{end+1}=o.legacy.(n{k});end
 if isfield(o,'extra_datasets'),e=[e o.extra_datasets];end
end
end
end
