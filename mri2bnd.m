function mri2bnd(cfg, subj)
%MRI2BND create volume, based on MRI
%
% CFG
%  .data: name of projects/PROJNAME/subjects/
%  .rec: name of the recordings (part of the structrual filename)
%  .vol.mod: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/
%  .vol.cond: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/VOLCONDNAME/
%
%  .mri2bnd.tpmthreshold: threshold for segmentation (1 default, 0.05 pretty sensitive)
%  .mri2bnd.numvertices: number of vertices ([2500 1200 1000])
%  .mri2bnd.threshbnd: threshold for mesh
%
% Part of MRI2LEAD
% see also CPMRI, MRI2BND, BND2LEAD, USETEMPLATE

%---------------------------%
%-start log
output = sprintf('(p%02.f) %s started at %s on %s\n', ...
  subj, mfilename, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'));
tic_t = tic;
%---------------------------%

%---------------------------%
%-dir and files
mdir = sprintf('%s%04.f/%s/%s/', cfg.data, subj, cfg.vol.mod, cfg.vol.cond); % mridata dir
mfile = sprintf('%s_%04.f_%s_%s', cfg.rec, subj, cfg.vol.mod, cfg.vol.cond); % mridata
ext = '.nii.gz';

mrifile = [mdir mfile cfg.normalize ext];
bndfile = [mdir mfile '_bnd'];
%---------------------------%

%-------------------------------------%
%-read and prepare mri
%-----------------%
%-read
mri = ft_read_mri(mrifile);
%-----------------%
 
%-----------------%
%-segmenting the volume, Tissue Probability Maps
cfg1 = [];
cfg1.threshold  = [];
cfg1.output = 'tpm';
cfg1.coordsys = 'spm';
tpm = ft_volumesegment(cfg1, mri);
tpm.anatomy = mri.anatomy;
%-----------------%

%-----------------%
%-segmenting the volume
cfg1 = [];
cfg1.threshold  = cfg.mri2bnd.tpmthreshold;
cfg1.output = 'scalp';
cfg1.coordsys = 'spm';
segscalp = ft_volumesegment(cfg1, tpm);

cfg1 = [];
cfg1.threshold  = [];
cfg1.output = {'skull' 'brain'};
cfg1.coordsys = 'spm';
segment = ft_volumesegment(cfg1, tpm);
segment.scalp = segscalp.scalp;

clear segscalp
%-----------------%
%-------------------------------------%

%-------------------------------------%
%-mesh and headmodel
M = segment.transform;

%-----------------%
%-prepare mesh for skull and brain (easy)
cfg2 = [];
cfg2.tissue = {'skull', 'brain'};
cfg2.numvertices = cfg.mri2bnd.numvertices(2:3);
cfg2.transform = M;
bnd = ft_prepare_mesh_new(cfg2, segment);
%-----------------%

%-----------------%
%-prepare mesh for scalp
cfg2 = [];
cfg2.tissue = {'scalp'};
cfg2.numvertices = cfg.mri2bnd.numvertices(1);
cfg2.thresholdseg = cfg.mri2bnd.threshbnd;
cfg2.transform = M;
scalp = ft_prepare_mesh_new(cfg2, segment);
%-----------------%

%-----------------%
%-combine scalp and bnd
bnd = [scalp bnd];

save(bndfile, 'bnd')
%-----------------%
%-------------------------------------%

%---------------------------%
%-end log
toc_t = toc(tic_t);
outtmp = sprintf('(p%02.f) %s ended at %s on %s after %s\n\n', ...
  subj, mfilename, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'), ...
  datestr( datenum(0, 0, 0, 0, 0, toc_t), 'HH:MM:SS'));
output = [output outtmp];

%-----------------%
fprintf(output)
fid = fopen([cfg.log '.txt'], 'a');
fwrite(fid, output);
fclose(fid);
%-----------------%
%---------------------------%