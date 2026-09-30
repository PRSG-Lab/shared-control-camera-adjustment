classdef IO
methods(Static)
function a=append(a,b)
 if isempty(a),a=b;elseif ~isempty(b),a=[a b];end
end
function file=source(file)
 if nargin<1||isempty(file)
  error('PR:SourceRequired','Pass the path to a completed v2.1 output.mat explicitly.');
 end
 if isfolder(file),file=fullfile(file,'output.mat');end
 file=char(java.io.File(file).getCanonicalPath());assert(isfile(file),'Source MAT not found');
 assert(jog2.Archive.isArchive(file),'PR:Format','Requires the completed v2.1 archive output.mat, not a flat legacy MAT.');
end
function [st,o]=begin(file,folder,opt,stage)
 validateattributes(opt.max_tasks,{'numeric'},{'scalar','positive'});
 validateattributes(opt.gaussian.draws,{'numeric'},{'scalar','integer','positive','finite'});
 validateattributes(opt.target.grid_size,{'numeric'},{'scalar','integer','>=',2});
 validateattributes(opt.target.depths,{'numeric'},{'vector','positive','finite'});
 validateattributes(opt.bias.steps,{'numeric'},{'vector','positive','finite'});
 validateattributes(opt.additional.batch_size,{'numeric'},{'scalar','integer','positive'});
 file=prrev.IO.source(file);o=jog2.Store.metadata(file);
 assert(isfield(o,'conditions')&&o.meta.complete,'Source raw simulation is incomplete');
 folder=char(java.io.File(folder).getCanonicalPath());
 assert(~strcmp(folder,fileparts(file)),'PR:SourceSafety','Choose a NEW folder, not the source run folder.');
 if ~isfolder(folder),mkdir(folder);end
 for x={'checkpoints','figures','tables'},if ~isfolder(fullfile(folder,x{1})),mkdir(fullfile(folder,x{1}));end,end
 identity=opt;identity=rmfield(identity,{'max_tasks','make_figures','dpi','source_file'});
 root=fileparts(fileparts(mfilename('fullpath')));code=dir(fullfile(root,'**','*.m'));sig={};
 for k=1:numel(code)
  fn=fullfile(code(k).folder,code(k).name);if contains(fn,[filesep 'results' filesep]),continue;end
  sig(end+1,:)={fn(numel(root)+2:end),jog2.Util.hash(fileread(fn))}; %#ok<AGROW>
 end
 [~,ii]=sort(sig(:,1));sig=sig(ii,:);
 entries=jog2.Store.entries(o);hashes=cellfun(@(e)e.sha256,entries,'UniformOutput',false);
 token=jog2.Util.hash(jsonencode(struct('stage',stage,'run',o.meta.run_id,'options',identity,'payload_hashes',{hashes},'code',{sig})));
 checkpoint=fullfile(folder,'checkpoint.mat');
 if isfile(checkpoint)
  a=load(checkpoint,'state');st=a.state;
  assert(strcmp(st.token,token)&&strcmp(st.source,file),'PR:ResumeMismatch','Source, computation settings or code changed. Use a NEW destination folder.');
 else
  assert(~isfile(fullfile(folder,'output.mat')),'Destination already contains output.mat');
  st=struct('schema_version','pr-revision-1.0','stage',stage,'token',token,'source',file,'folder',folder,...
   'options',opt,'source_run',o.meta.run_id,'source_config',o.config,'code_manifest',{sig},'entries',{{}},'results',struct(),'complete',false,'created_utc',jog2.Util.utc());
  prrev.IO.save(st);
 end
end
function save(st)
 jog2.Util.saveAtomic(fullfile(st.folder,'checkpoint.mat'),'state',st);
end
function [yes,v]=cached(st,key)
 yes=false;v=[];p=fullfile(st.folder,'checkpoints',[key '.mat']);
 if isfile(p),a=load(p,'record');assert(strcmp(a.record.token,st.token),'PR:CacheMismatch','Invalid checkpoint identity');yes=true;v=a.record.value;end
end
function st=put(st,key,v)
 p=fullfile(st.folder,'checkpoints',[key '.mat']);
 [yes,~]=prrev.IO.cached(st,key);
 if ~yes,record=struct('token',st.token,'value',v);jog2.Util.saveAtomic(p,'record',record);end
 if ~any(cellfun(@(e)strcmp(e.prefix,key),st.entries))
  st.entries{end+1}=struct('prefix',key,'kind','pr_record','file',fullfile('checkpoints',[key '.mat']),...
   'sha256',jog2.Util.filehash(p),'bytes',dir(p).bytes);
 end
 prrev.IO.save(st);
end
function out=finish(st,results)
 st.results=results;st.complete=true;st.completed_utc=jog2.Util.utc();prrev.IO.save(st);
 out=fullfile(st.folder,'output.mat');partial=fullfile(st.folder,'output.packing.mat');
 output=rmfield(st,{'folder','entries'});output.data_index=st.entries;
 output.storage='load(file,output) for summaries; pr_read_payload for complete per-batch records';
 if isfile(out)
  a=load(out,'output');assert(strcmp(a.output.token,st.token),'Output identity conflict');return;
 end
 if ~isfile(partial),jog2.Archive.create(partial,output);end
 for k=1:numel(st.entries)
  e=st.entries{k};if jog2.Archive.ready(partial,e),continue;end
  jog2.Archive.putFile(partial,e,fullfile(st.folder,e.file));
  if mod(k,20)==0||k==numel(st.entries),fprintf('Pack %d/%d records\n',k,numel(st.entries));end
 end
 for k=1:numel(st.entries),assert(jog2.Archive.ready(partial,st.entries{k}),'Incomplete payload');end
 jog2.Store.saveMetadata(partial,output);movefile(partial,out,'f');
 fprintf('Complete: %s\n',out);
end
function stop=pause(opt,done)
 stop=done>=opt.max_tasks;
 if stop,fprintf('Paused after %d new tasks. Run the SAME command/folder to resume.\n',done);end
end
function s=summary(o,c)
 ix=find(cellfun(@(x)strcmp(x.prefix,c.prefix),o.conditions),1);
 assert(~isempty(ix)&&numel(o.summaries)>=ix&&~isempty(o.summaries{ix}),'Source summary missing');s=o.summaries{ix};
end
end
end
