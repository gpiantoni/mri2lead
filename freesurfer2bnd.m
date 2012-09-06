function freesurfer2bnd(cfg, subj)
%FREESURFER2BND create volume, based on freesurfer 
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
%  .fs2bnd.smudgeiter: iteration for smudging (default = 6) (it's possible to
%               rerun this function, only to change the amount of smudging)
%
% IN
%  You should run freesurfer and you need to create a watershed folder. It
%  should have a "fsaverage" subject, to project the activity to.
%  It reads the folder cfg.SUBJECTS_DIR and the subject code in it (the
%  subject code here and in freesurfer should match!)
% 
% OUT
%  bnd: three-layer BEM, based on 'outer_skin' 'inner_skull'  'brain' in watershed
%       note that the tutorial on fieldtrip uses 'inner_skull' 'outer_skull' 'outer_skin'
%  grid: location of the dipoles in the head
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
%-------%
%-surf
sdir = sprintf('%s%04d/%s', cfg.SUBJECTS_DIR, subj, 'surf/');
%-------%

%-------%
%-watershed
wdir = sprintf('%s%04d/%s', cfg.SUBJECTS_DIR, subj, 'bem/watershed/');
wfile = sprintf('%04d_', subj);
%-------%

%-------%
%-output files
mdir = sprintf('%s%04.f/%s/%s/', cfg.data, subj, cfg.vol.mod, cfg.vol.cond); % mridata dir
mfile = sprintf('%s_%04.f_%s_%s', cfg.rec, subj, cfg.vol.mod, cfg.vol.cond); % mridata
bndfile = [mdir mfile '_bnd'];
gridfile = [mdir mfile '_grid'];
%-------%
%---------------------------%

%---------------------------%
%-surfaces
surface = {'outer_skin' 'inner_skull'  'brain'};

if ~isfield(cfg, 'surftype'); cfg.surftype = 'smoothwm'; end
if ~isfield(cfg.fs2bnd, 'smudgeiter'); cfg.fs2bnd.smudgeiter = 6; end
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
hemi = {'lh.' 'rh.'};
for i = 1:numel(hemi)
  highres = ft_read_headshape([sdir hemi{i} cfg.surftype]);
  lowres{i} = reducebnd(highres, cfg.fs2bnd.reducegrid);
  
  %-------%
  %-use smudge, from fieldtrip/private
  [datin, loc] = ismember(highres.pnt, lowres{i}.pnt, 'rows');
  [datout, S1] = smudge(datin, highres.tri, cfg.fs2bnd.smudgeiter);
  
  sel = find(datin);
  S2  = sparse(sel(:), loc(datin), ones(size(lowres{i}.pnt,1),1), size(highres.pnt,1), size(lowres{i}.pnt,1));
  interpmat{i} = S1 * S2;
  %-------%
  
end

grid.pos = [lowres{1}.pnt; lowres{2}.pnt];
save(gridfile, 'grid', 'lowres', 'interpmat')
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

