function file=RUN_RESUME(destination,max_batches)
% Resume exactly the same package/configuration/destination checkpoint.
% A budget limits NEW tasks in the active stage, then saves and returns.
if nargin<2,max_batches=Inf;end
assert(nargin>=1&&isfolder(destination),'Pass the existing run folder.');
file=prpaper_run('resume',struct('destination',destination,'max_batches',max_batches));
end
