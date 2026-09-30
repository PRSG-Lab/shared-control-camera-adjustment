function value=pr_read_payload(file,prefix)
% Read one verified embedded checkpoint. output.mat remains self-contained.
pr_setup();a=load(file,'output');idx=find(cellfun(@(e)strcmp(e.prefix,prefix),a.output.data_index),1);
assert(~isempty(idx),'Unknown payload prefix');e=a.output.data_index{idx};
[tmp,cleanup]=jog2.Archive.extract(file,e);s=load(tmp,'record');value=s.record.value;
end
