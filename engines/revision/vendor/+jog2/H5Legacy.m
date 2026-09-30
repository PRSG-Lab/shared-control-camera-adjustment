classdef H5Legacy
%H5LEGACY Bounded subtree reader for dense structs/cells in MATLAB v7.3.
% Uses official HDF5 object references; does not load the top-level output.
methods(Static)
function v=read(file,path,indices)
 if nargin<3,indices=[];end
 info=h5info(file,path);
 if isfield(info,'Datasets')
  names={};if ~isempty(info.Datasets),names={info.Datasets.Name};end
  if ~isempty(info.Groups),names=[names {info.Groups.Name}];end;fields=struct();isref=false(1,numel(names));
  for k=1:numel(names)
   name=names{k};if startsWith(name,'/'),[~,field]=fileparts(name);child=name;else,field=name;child=[path '/' name];end
   ci=h5info(file,child);cls=jog2.H5Legacy.attribute(ci,'MATLAB_class','');
   isref(k)=isfield(ci,'Datatype')&&strcmp(ci.Datatype.Class,'H5T_REFERENCE')&&isempty(cls);
   fields.(field)=jog2.H5Legacy.read(file,child);
  end
  if any(isref)
   fn=fieldnames(fields);a=find(isref,1);shape=size(fields.(fn{a}));v=repmat(struct(),shape);
   for k=1:numel(fn)
    x=fields.(fn{k});
    for z=1:numel(v),if isref(k),v(z).(fn{k})=x{z};else,v(z).(fn{k})=x;end,end
   end
  else,v=fields;end
  return;
 end
 cls=jog2.H5Legacy.attribute(info,'MATLAB_class','');
 emptyflag=jog2.H5Legacy.attribute(info,'MATLAB_empty',0);
 if strcmp(info.Datatype.Class,'H5T_REFERENCE')
  fid=H5F.open(file);cf=onCleanup(@()H5F.close(fid));ds=H5D.open(fid,path);cd=onCleanup(@()H5D.close(ds));
  raw=H5D.read(ds);raw=reshape(raw,size(raw,1),[]);space=H5D.get_space(ds);[~,dims]=H5S.get_simple_extent_dims(space);H5S.close(space);
  shape=fliplr(dims);if numel(shape)<2,shape=[shape 1];end
  allidx=1:size(raw,2);if ~isempty(indices),allidx=indices;shape=[1 numel(indices)];end
  v=cell(shape);
  for z=1:numel(allidx)
   ref=raw(:,allidx(z));obj=H5R.dereference(ds,'H5R_OBJECT',ref);target=H5I.get_name(obj);H5O.close(obj);
   v{z}=jog2.H5Legacy.read(file,target);
  end
 else
  v=h5read(file,path);
  if emptyflag
   dims=double(v(:)');if isempty(dims),dims=[0 0];end;if numel(dims)<2,dims=[dims 0];end
   if strcmp(cls,'cell'),v=cell(dims);elseif strcmp(cls,'char'),v=char(zeros(dims));else,v=zeros(dims);end
  elseif strcmp(cls,'char'),v=char(v);
  elseif strcmp(cls,'logical'),v=logical(v);
  elseif isstruct(v)&&isfield(v,'real')&&isfield(v,'imag'),v=complex(v.real,v.imag);
  end
 end
end
function a=attribute(info,name,fallback)
 a=fallback;if isempty(info.Attributes),return;end
 idx=find(strcmp({info.Attributes.Name},name),1);
 if ~isempty(idx),a=info.Attributes(idx).Value;if isstring(a),a=char(a);end,end
end
function n=count(file,path)
 info=h5info(file,path);n=prod(info.Dataspace.Size);
end
end
end
