function freesurfer2bnd(cfg, subj)
%FREESURFER2BND create volume, based on freesurfer 
% You need the watershed folder here
%
% CFG
%  .data: name of projects/PROJNAME/subjects/
%  .rec: name of the recordings (part of the structrual filename)
%  .vol.mod: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/
%  .vol.cond: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/VOLCONDNAME/
%  
%  .SUBJECTS_DIR: where the Freesurfer data is stored (like the environmental variable)
%  .surftype: name of the surface to read ('smoothwm' 'pial' 'white' 'inflated' 'orig' 'sphere')
%  .fs2bnd.reducesurf: ratio to reducepatch of surface (1 -> intact, .5 -> half)
%  .fs2bnd.reducegrid: ratio to reducepatch of source grid (1 -> intact, .5 -> half)
%
% Part of MRI2LEAD
% see also CPMRI, MRI2BND, FREESURFER2BND, BND2LEAD, USETEMPLATE

%---------------------------%
%-start log
output = sprintf('%s (%04d) began at %s on %s\n', ...
  mfilename, subj, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'));
tic_t = tic;
%---------------------------%

%---------------------------%
%-dir and files
%-watershed
wdir = sprintf('%s%04d/%s', cfg.SUBJECTS_DIR, subj, 'bem/watershed/');
wfile = sprintf('%04d_', subj);

%-surf
sdir = sprintf('%s%04d/%s', cfg.SUBJECTS_DIR, subj, 'surf/');

mdir = sprintf('%s%04.f/%s/%s/', cfg.data, subj, cfg.vol.mod, cfg.vol.cond); % mridata dir
mfile = sprintf('%s_%04.f_%s_%s', cfg.rec, subj, cfg.vol.mod, cfg.vol.cond); % mridata
bndfile = [mdir mfile '_bnd'];
gridfile = [mdir mfile '_grid'];
%---------------------------%

%---------------------------%
%-surfaces
% note that the tutorial on fieldtrip uses 
% {'inner_skull' 'outer_skull' 'outer_skin'}
surface = {'outer_skin' 'inner_skull'  'brain'};

if ~isfield(cfg, 'surftype'); cfg.surftype = 'smoothwm'; end
%---------------------------%

%---------------------------%
%-read the surface
for i = 1:numel(surface)
  bndtmp = ft_read_headshape([wdir wfile surface{i} '_surface']);
  
  bnd(i) = reducebnd(bndtmp, cfg.fs2bnd.reducesurf);
end

save(bndfile, 'bnd')
%---------------------------%

%---------------------------%
%-prepare grid
gridlh = ft_read_headshape([sdir 'lh.' cfg.surftype]);
gridlh = reducebnd(gridlh, cfg.fs2bnd.reducegrid);
eval(['lh_' cfg.surftype ' = gridlh;'])

gridrh = ft_read_headshape([sdir 'rh.' cfg.surftype]);
gridrh = reducebnd(gridrh, cfg.fs2bnd.reducegrid);
eval(['rh_' cfg.surftype ' = gridrh;'])

grid.pos = [gridlh.pnt; gridrh.pnt];
save(gridfile, 'grid', ['lh_' cfg.surftype], ['rh_' cfg.surftype])
%---------------------------%

%---------------------------%
%-end log
toc_t = toc(tic_t);
outtmp = sprintf('%s (%04d) ended at %s on %s after %s\n\n', ...
  mfilename, subj, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'), ...
  datestr( datenum(0, 0, 0, 0, 0, toc_t), 'HH:MM:SS'));
output = [output outtmp];

%-----------------%
fprintf(output)
fid = fopen([cfg.log '.txt'], 'a');
fwrite(fid, output);
fclose(fid);
%-----------------%
%---------------------------%

%---------------------------%
%-SUBFUNCTION: reducebnd
function bndtmp = reducebnd(bndtmp, reducesurf)

P.faces = bndtmp.tri;
P.vertices = bndtmp.pnt;
P = reducepatch(P, reducesurf);
bndtmp.tri = P.faces;
bndtmp.pnt = P.vertices;
%---------------------------%

