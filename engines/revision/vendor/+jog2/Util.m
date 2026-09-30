classdef Util
methods(Static)
function h=hash(x)
 if ~isa(x,'uint8'),x=unicode2native(char(x),'UTF-8');end
 d=java.security.MessageDigest.getInstance('SHA-256');d.update(x);
 h=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2)',1,[]));
end
function h=filehash(path)
 f=fopen(path,'rb');assert(f>=0);cl=onCleanup(@()fclose(f));
 d=java.security.MessageDigest.getInstance('SHA-256');expected=dir(path);count=0;
 while count<expected.bytes,x=fread(f,min(2^20,expected.bytes-count),'*uint8');if isempty(x),break;end;count=count+numel(x);d.update(x);end
 [message,err]=ferror(f);
 assert(err==0&&count==expected.bytes,'jog2:SourceReadFailed',...
 'Cannot read the complete source file (%d/%d bytes): %s. Ensure cloud files are downloaded and readable. %s',count,expected.bytes,path,message);
 h=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2)',1,[]));
end
function s=sources()
 root=fileparts(fileparts(mfilename('fullpath')));
 files=dir(fullfile(root,'**','*.m'));s=struct('name',{},'text',{},'sha256',{});
 for i=1:numel(files)
  fn=fullfile(files(i).folder,files(i).name);
  if contains(fn,[filesep 'results' filesep]),continue;end
  a.name=fn(numel(root)+2:end);a.text=fileread(fn);a.sha256=jog2.Util.hash(a.text);
  s(end+1)=a;
 end
 [~,ix]=sort({s.name});s=s(ix);
end
function [r,sid]=stream(cfg,j,g,c,k,role)
 assert(j>=10&&j<=16&&g>=0&&g<100&&c>=0&&c<100&&k>=0&&k<10000&&role>=0&&role<8,'RNG tuple out of range');
 sid=1+(((((j-10)*100+g)*100+c)*10000+k)*8+role);
 r=RandStream(cfg.rng_type,'Seed',cfg.revision_seed,'NormalTransform',cfg.normal_transform);
 r.Substream=sid;
end
function r=analysisStream(cfg,job,rep)
 assert(rep>=0&&rep<10000&&job>=0);
 r=RandStream('mrg32k3a','Seed',cfg.analysis_seed,'NormalTransform','Inversion');
 r.Substream=1+job*10000+rep;
end
function F=psdfactor(Q)
 Q=(Q+Q')/2;if isempty(Q),F=zeros(size(Q,1),0);return;end
 [F,p]=chol(Q,'lower');if p==0,return;end
 [V,D]=eig(Q);d=diag(D);tol=1e-12*max(abs(d));
 if isempty(tol)||tol==0,F=zeros(size(Q,1),0);return;end
 assert(min(d)>=-tol,'jog2:PSD','Covariance is not PSD');
 keep=d>tol;F=V(:,keep)*diag(sqrt(d(keep)));
end
function v=camvec(c)
 if isempty(c),v=nan(16,1);else,v=[c.gamma;c.R(:);c.phi;c.kappa;c.pp];end
end
function c=vecCam(v,scale)
 if any(~isfinite(v)),c=[];return;end
 c=struct('gamma',v(1:3),'R',reshape(v(4:12),3,3),'phi',v(13),...
 'kappa',v(14),'pp',v(15:16),'scale',scale);
end
function S=without(S,names)
 for k=1:numel(names),if isfield(S,names{k}),S=rmfield(S,names{k});end,end
end
function saveAtomic(file,name,value)
 tmp=[file '.partial.mat'];s=struct();s.(name)=value;save(tmp,'-struct','s','-v7.3');
 [ok,msg]=movefile(tmp,file,'f');assert(ok,msg);
end
function t=utc()
 t=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss Z'));
end
end
end
