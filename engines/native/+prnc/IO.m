classdef IO
methods(Static)
function p=canonical(p)
 p=char(java.io.File(p).getCanonicalPath());
end
function h=hash(x)
 if ~isa(x,'uint8'),x=unicode2native(char(x),'UTF-8');end
 d=java.security.MessageDigest.getInstance('SHA-256');d.update(x(:));
 h=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2)',1,[]));
end
function h=filehash(p)
 f=fopen(p,'rb');assert(f>=0,'Cannot read %s',p);cl=onCleanup(@()fclose(f));
 d=java.security.MessageDigest.getInstance('SHA-256');n=0;s=dir(p);
 while n<s.bytes
  x=fread(f,min(2^20,s.bytes-n),'*uint8');if isempty(x),break;end
  d.update(x);n=n+numel(x);
 end
 [msg,err]=ferror(f);assert(err==0&&n==s.bytes,'Incomplete source read: %s %s',p,msg);
 h=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2)',1,[]));
end
function save(p,name,value)
 % Same-directory temporary file; interrupting cannot replace a complete file.
 tmp=[p '.partial.mat'];a=struct();a.(name)=value;save(tmp,'-struct','a','-v7.3');
 [ok,msg]=movefile(tmp,p,'f');assert(ok,msg);
end
function remove(p)
 if isfile(p),delete(p);end
end
function [o,pr,source,meta]=sources(root,opt)
 root=prnc.IO.canonical(root);
 if isfolder(root),prfile=fullfile(root,'results','postprocess_paper','output.mat');else,prfile=root;end
 assert(isfile(prfile),'PRNC:MissingPR','Missing completed PR postprocess output: %s',prfile);
 a=load(prfile,'output');pr=a.output;
 assert(isfield(pr,'complete')&&pr.complete&&strcmp(pr.stage,'postprocess'),'Incomplete/wrong PR stage');
 source=opt.original_file;
 if isempty(source),source=pr.source;end
 if ~isfile(source)
  error('PRNC:MissingOriginal',['The PR summaries do not contain the original J12 fitted cameras. ',...
   'Set opt.original_file to the ORIGINAL completed v2.1 output.mat. Expected path: %s'],source);
 end
 source=prnc.IO.canonical(source);a=load(source,'output');o=a.output;
 assert(isfield(o,'meta')&&o.meta.complete&&o.meta.analysis_complete,'Original raw data and analysis must be complete');
 assert(strcmp(o.schema_version,'jog-output-2.1'),'Expected v2.1 archive');
 assert(strcmp(o.meta.run_id,pr.source_run),'PRNC:WrongRun','Original run does not match PR provenance');
 s=dir(source);p=dir(prfile);
 meta=struct('pr_file',prfile,'pr_token',pr.token,'pr_bytes',p.bytes,...
  'pr_datenum',p.datenum,'source_file',source,'source_run',o.meta.run_id,...
  'source_config_hash',o.meta.config_hash,'source_bytes',s.bytes,'source_datenum',s.datenum,...
  'source_pr_sha256',prnc.IO.filehash(prfile),...
  'verification','Every consumed original MAT payload is SHA-256 checked against its metadata entry.');
end
function value=read(file,entry,fields)
 % Read only one bounded archived MAT shard; NEVER load the large file whole.
 if nargin<3,fields={};end
 dataset=['/jog_payload/' entry.prefix];
 assert(h5readatt(file,dataset,'committed')==1,'Uncommitted source payload');
 digest=h5readatt(file,dataset,'sha256');
 assert(strcmp(digest,entry.sha256),'PRNC:Hash','Archive metadata checksum mismatch');
 info=h5info(file,dataset);n=prod(info.Dataspace.Size);
 assert(n==entry.bytes,'Source payload size mismatch');
 tmp=[tempname '.mat'];cleanup=onCleanup(@()prnc.IO.remove(tmp));
 f=fopen(tmp,'wb');assert(f>=0);closefile=onCleanup(@()fclose(f));
 md=java.security.MessageDigest.getInstance('SHA-256');
 for first=1:2^20:n
  count=min(2^20,n-first+1);x=h5read(file,dataset,[first 1],[count 1]);
  assert(fwrite(f,x,'uint8')==numel(x),'Temporary disk write failed');md.update(x(:));
 end
 clear closefile
 actual=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[]));
 assert(strcmp(actual,entry.sha256),'PRNC:Hash','Source payload checksum failed');
 if strcmp(entry.kind,'batch')
  names=cellfun(@(s)[entry.prefix '_' s],fields,'UniformOutput',false);
  a=load(tmp,names{:});value=struct();
  for k=1:numel(fields),assert(isfield(a,names{k}),'Missing saved field %s',fields{k});value.(fields{k})=a.(names{k});end
 else
  a=load(tmp,entry.prefix);value=a.(entry.prefix);
 end
end
function c=manifest(root)
 a=dir(fullfile(root,'**','*.m'));c=cell(0,2);
 for k=1:numel(a)
  f=fullfile(a(k).folder,a(k).name);rel=f(numel(root)+2:end);
  if startsWith(rel,['results' filesep])||startsWith(rel,['validation' filesep]),continue;end
  c(end+1,:)={rel,prnc.IO.filehash(f)}; %#ok<AGROW>
 end
 [~,ix]=sort(c(:,1));c=c(ix,:);
end
function [hit,v]=cached(folder,key,token)
 p=fullfile(folder,'checkpoints',[key '.mat']);hit=isfile(p);v=[];
 if hit,a=load(p,'record');assert(strcmp(a.record.token,token),'PRNC:StaleCache','Settings/source/code changed. Use a new destination.');v=a.record.value;end
end
function put(folder,key,token,value)
 record=struct('token',token,'value',{value});
 prnc.IO.save(fullfile(folder,'checkpoints',[key '.mat']),'record',record);
end
end
end
