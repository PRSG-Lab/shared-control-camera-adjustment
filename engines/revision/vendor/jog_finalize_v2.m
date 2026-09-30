function file=jog_finalize_v2(folder,varargin)
p=inputParser;addParameter(p,'SourceRuns',{});addParameter(p,'EmbedSourceData',true);parse(p,varargin{:});
assert(p.Results.EmbedSourceData,'Final output must embed all source raw data');
file=jog2.Store.finalize(folder,p.Results.SourceRuns);
end
