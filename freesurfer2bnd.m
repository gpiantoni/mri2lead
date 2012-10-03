function freesurfer2bnd(info, opt, subj)
%FREESURFER2BND create mesh based on MRI using freesurfer
%
% INFO
%  .data: path of /data1/projects/PROJ/subjects/
%  .rec: REC in /data1/projects/PROJ/recordings/REC/
%  .vol.mod: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/
%  .vol.cond: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/VOLCONDNAME/
%  .log: name of the file and directory to save log
%
% CFG.OPT
%  .SUBJECTS_DIR*: where the Freesurfer data is stored (like the environmental variable), with extra slash 
%  .surftype: name of the surface to read ('smoothwm' 'pial' 'white' 'inflated' 'orig' 'sphere')
%  .reducesurf*: ratio to reducepatch of surface (1 -> intact, .5 -> half)
%  .reducegrid*: ratio to reducepatch of source grid (1 -> intact, .5 -> half)
%  .smudgeiter: iteration for smudging (default = 6) (it's possible to
%               rerun this function, only to change the amount of smudging) 
%
% * indicates obligatory parameter
%
% IN
%  You should run freesurfer and you need to create a watershed folder. It
%  should have a "fsaverage" subject, to project the activity to.
%  It reads the folder cfg.opt.SUBJECTS_DIR and the subject code in it (the
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
sdir = sprintf('%s%04d/%s', opt.SUBJECTS_DIR, subj, 'surf/');
%-------%

%-------%
%-watershed
wdir = sprintf('%s%04d/%s', opt.SUBJECTS_DIR, subj, 'bem/watershed/');
wfile = sprintf('%04d_', subj);
%-------%

%-------%
%-output files
mdir = sprintf('%s%04d/%s/%s/', info.data, subj, info.vol.mod, info.vol.cond); % mridata dir
mfile = sprintf('%s_%04d_%s_%s', info.rec, subj, info.vol.mod, info.vol.cond); % mridata
bndfile = [mdir mfile '_bnd'];
gridfile = [mdir mfile '_grid'];
%-------%
%---------------------------%

%---------------------------%
%-surfaces
surface = {'outer_skin' 'inner_skull'  'brain'};

if ~isfield(opt, 'surftype'); opt.surftype = 'smoothwm'; end
if ~isfield(opt, 'smudgeiter'); opt.smudgeiter = 6; end
%---------------------------%

%---------------------------%
%-read the surface
for i = 1:numel(surface)
  bndtmp = ft_read_headshape([wdir wfile surface{i} '_surface']);
  
  bnd(i) = reducebnd(bndtmp, opt.reducesurf);
end

save(bndfile, 'bnd')
%---------------------------%

%---------------------------%
%-prepare grid
hemi = {'lh.' 'rh.'};
for i = 1:numel(hemi)
  highres = ft_read_headshape([sdir hemi{i} opt.surftype]);
  lowres{i} = reducebnd(highres, opt.reducegrid);
  
  %-------%
  %-use smudge, from fieldtrip/private
  [datin, loc] = ismember(highres.pnt, lowres{i}.pnt, 'rows');
  [datout, S1] = smudge(datin, highres.tri, opt.smudgeiter);
  
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
fid = fopen([info.log '.txt'], 'a');
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

