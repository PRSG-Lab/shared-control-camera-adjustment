classdef Archive
%ARCHIVE Self-contained MAT payloads without a flat MATLAB variable directory.
% /jog_payload/<prefix> contains bytes of one ordinary, bounded MAT shard.
% MATLAB load(file,'output') reads metadata; Store.read decodes payloads.
methods(Static)
function tf=isArchive(file)
 tf=false;if ~exist(file,'file'),return;end
 try,f=H5F.open(file,'H5F_ACC_RDONLY','H5P_DEFAULT');c=onCleanup(@()H5F.close(f));tf=H5L.exists(f,'/jog_payload','H5P_DEFAULT');catch,end
end
function create(file,o)
 output=o;save(file,'output','-v7.3');
 h5create(file,'/jog_payload/format_version',[1 1],'Datatype','uint8');h5write(file,'/jog_payload/format_version',uint8(1));
 h5writeatt(file,'/jog_payload','format','MAT-shard-bytes-v1');
end
function n=rootCount(file)
 f=H5F.open(file,'H5F_ACC_RDONLY','H5P_DEFAULT');c=onCleanup(@()H5F.close(f));
 g=H5G.open(f,'/');cg=onCleanup(@()H5G.close(g));i=H5G.get_info(g);n=double(i.nlinks);
end
function path=path(e)
 path=['/jog_payload/' e.prefix];
end
function tf=ready(file,e,token)
 if nargin<3,token='';end
 tf=false;path=jog2.Archive.path(e);
 try
  tf=h5readatt(file,path,'committed')==1;
  if isfield(e,'sha256')&&~isempty(e.sha256),tf=tf&&strcmp(h5readatt(file,path,'sha256'),e.sha256);end
  if ~isempty(token),tf=tf&&strcmp(h5readatt(file,path,'analysis_token'),token);end
 catch,tf=false;end
end
function e=normalize(e)
 if isfield(e,'variables'),e=rmfield(e,'variables');end
 e.archive_path=jog2.Archive.path(e);
end
function e=putFile(file,e,source,token)
 if nargin<4,token='';end
 % Verify immutable source before reusing a completed copy.
 hash=jog2.Util.filehash(source);
 if isfield(e,'sha256')&&~isempty(e.sha256),assert(strcmp(hash,e.sha256),'jog2:SourceChecksum','Source checksum mismatch: %s',source);end
 e.sha256=hash;e.bytes=dir(source).bytes;e=jog2.Archive.normalize(e);
 if jog2.Archive.ready(file,e,token),return;end
 path=e.archive_path;
 fid=H5F.open(file,'H5F_ACC_RDWR','H5P_DEFAULT');
 if H5L.exists(fid,path,'H5P_DEFAULT'),H5L.delete(fid,path,'H5P_DEFAULT');end;H5F.close(fid);
 chunk=min(2^20,e.bytes);assert(chunk>0);
 h5create(file,path,[e.bytes 1],'Datatype','uint8','ChunkSize',[chunk 1]);
 h5writeatt(file,path,'committed',uint8(0));
 f=fopen(source,'rb');assert(f>=0);cl=onCleanup(@()fclose(f));at=1;
 while at<=e.bytes
  x=fread(f,min(chunk,e.bytes-at+1),'*uint8');assert(~isempty(x));h5write(file,path,x,[at 1],[numel(x) 1]);at=at+numel(x);
 end
 h5writeatt(file,path,'sha256',hash);h5writeatt(file,path,'kind',e.kind);
 h5writeatt(file,path,'analysis_token',token);h5writeatt(file,path,'committed',uint8(1));
end
function e=putValue(file,prefix,value,kind,token)
 if nargin<5,token='';end
 tmp=[tempname '.mat'];cl=onCleanup(@()jog2.Archive.removeTemp(tmp));vars=struct();
 if strcmp(kind,'batch'),names=fieldnames(value);for k=1:numel(names),vars.([prefix '_' names{k}])=value.(names{k});end
 else,vars.(prefix)=value;end
 save(tmp,'-struct','vars','-v7.3');
 e=struct('prefix',prefix,'kind',kind,'file','','sha256','','bytes',0);
 e=jog2.Archive.putFile(file,e,tmp,token);
end
function [path,clean]=extract(file,e)
 assert(jog2.Archive.ready(file,e),'jog2:PayloadIncomplete','Incomplete/missing payload: %s',e.prefix);
 path=[tempname '.mat'];clean=onCleanup(@()jog2.Archive.removeTemp(path));
 dataset=jog2.Archive.path(e);info=h5info(file,dataset);n=prod(info.Dataspace.Size);
 f=fopen(path,'wb');assert(f>=0);cf=onCleanup(@()fclose(f));
 digest=java.security.MessageDigest.getInstance('SHA-256');chunk=2^20;
 for first=1:chunk:n
  x=h5read(file,dataset,[first 1],[min(chunk,n-first+1) 1]);fwrite(f,x,'uint8');digest.update(x(:));
 end
 clear cf;
 hash=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[]));
 assert(strcmp(hash,h5readatt(file,dataset,'sha256')),'jog2:PayloadChecksum','Payload checksum mismatch');
end
function v=read(file,e)
 [tmp,clean]=jog2.Archive.extract(file,e);s=load(tmp); %#ok<NASGU>
 v=jog2.Archive.unpack(s,e);
end
function v=unpack(s,e)
 if strcmp(e.kind,'batch')
  v=struct();fn=fieldnames(s);
  for k=1:numel(fn),assert(startsWith(fn{k},[e.prefix '_']));v.(fn{k}(numel(e.prefix)+2:end))=s.(fn{k});end
 else,v=s.(e.prefix);end
end
function e=entry(file,prefix,kind)
 e=struct('prefix',prefix,'kind',kind,'file','','sha256',h5readatt(file,['/jog_payload/' prefix],'sha256'),...
 'bytes',prod(h5info(file,['/jog_payload/' prefix]).Dataspace.Size),'archive_path',['/jog_payload/' prefix]);
end
function removeTemp(file)
 if exist(file,'file'),delete(file);end
end
end
end
