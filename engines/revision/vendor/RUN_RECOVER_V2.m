% Recovery of completed simulations. Select the OLD paper run folder.
% Run this script from the NEW v2.1 package folder after stopping old analysis.
source=uigetdir(pwd,'Select OLD paper run folder containing checkpoint.mat');
if isequal(source,0),return;end
% Stable destination: running this script again resumes packing/analysis.
[~,runname]=fileparts(source);
destination=fullfile(pwd,'results',[runname '_recovered']);
jog_recover_v2(source,destination);
